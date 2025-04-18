create database if not exists cortex_investment_analysis_demo;
use database cortex_investment_analysis_demo;
use schema public;

-- Create a compute warehouse for Cortex operations
CREATE OR REPLACE WAREHOUSE investment_cortex_wh 
WITH WAREHOUSE_SIZE = 'LARGE'
  AUTO_SUSPEND = 300
  AUTO_RESUME = TRUE
;

use warehouse investment_cortex_wh;

create or replace stage docs ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE') DIRECTORY = ( ENABLE = true );

-- Upload Financial News pdf to stage using Snowsight
ls @docs;



------------------------
-- Create the chunks table with enhanced metadata
CREATE OR REPLACE TABLE DOCS_CHUNKS_TABLE (
    RELATIVE_PATH VARCHAR(16777216),
    SIZE NUMBER(38,0),
    FILE_URL VARCHAR(16777216),
    SCOPED_FILE_URL VARCHAR(16777216),
    CHUNK VARCHAR(16777216),
    CATEGORY VARCHAR(16777216),
    PROCESSED_TIMESTAMP TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

------------
create or replace function text_chunker(pdf_text string)
returns table (chunk varchar)
language python
runtime_version = '3.9'
handler = 'text_chunker'
packages = ('snowflake-snowpark-python', 'langchain')
as
$$
from snowflake.snowpark.types import StringType, StructField, StructType
from langchain.text_splitter import RecursiveCharacterTextSplitter
import pandas as pd

class text_chunker:

    def process(self, pdf_text: str):
        
        text_splitter = RecursiveCharacterTextSplitter(
            chunk_size = 1512, #Adjust this as you see fit
            chunk_overlap  = 256, #This let's text have some form of overlap. Useful for keeping chunks contextual
            length_function = len
        )
    
        chunks = text_splitter.split_text(pdf_text)
        df = pd.DataFrame(chunks, columns=['chunks'])
        
        yield from df.itertuples(index=False, name=None)
$$;

-----------------
INSERT OVERWRITE INTO DOCS_CHUNKS_TABLE (
    RELATIVE_PATH, 
    SIZE, 
    FILE_URL,
    SCOPED_FILE_URL, 
    CHUNK,
    CATEGORY
)
WITH DocumentContent AS (
    SELECT 
        relative_path,
        size,
        file_url,
        TO_VARCHAR(
            SNOWFLAKE.CORTEX.PARSE_DOCUMENT(
                @docs, 
                relative_path, 
                {'mode': 'LAYOUT'}
            )
        ) AS document_text
    FROM directory(@docs)
),
CategorizedContent AS (
    SELECT 
        relative_path,
        size,
        file_url,
        document_text,
        relative_path as category
    FROM DocumentContent
)
SELECT 
    relative_path, 
    size,
    file_url, 
    build_scoped_file_url(@docs, relative_path) as scoped_file_url,
    func.chunk as chunk,
    category
FROM 
    CategorizedContent,
    TABLE(text_chunker(document_text)) as func;

--------------------------------------------
create or replace CORTEX SEARCH SERVICE financial_news_search
ON chunk
ATTRIBUTES category
warehouse = investment_cortex_wh
TARGET_LAG = '1 minute'
EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
as (
    select chunk,
        relative_path,
        file_url,
        category
    from docs_chunks_table
);


-- You can also use the CORTEX_SEARCH_DATA_SCAN table function to inspect the contents of the service.
SELECT
  *
FROM
  TABLE (
    CORTEX_SEARCH_DATA_SCAN (
      SERVICE_NAME => 'financial_news_search'
    )
  );


select category from docs_chunks_table group by category;

LIST @DOCS PATTERN = '.*\.pdf';

-------------------------------------------
CREATE OR REPLACE TABLE portfolio_holdings (
    investor_id VARCHAR(10),
    asset_symbol VARCHAR(10),
    quantity INT,
    purchase_price DECIMAL(10,2),
    current_price DECIMAL(10,2),
    sector VARCHAR(50)  -- Added sector column
);

INSERT OVERWRITE INTO portfolio_holdings VALUES
    ('INV001', 'AAPL', 100, 150.00, 180.00, 'Information Technology'),
    ('INV001', 'GOOGL', 50, 2800.00, 2900.00, 'Communication Services'),
    ('INV001', 'TSLA', 75, 700.00, 650.00, 'Consumer Discretionary'),
    ('INV002', 'MSFT', 200, 300.00, 320.00, 'Information Technology'),
    ('INV002', 'AMZN', 80, 3400.00, 3300.00, 'Consumer Discretionary'),
    ('INV002', 'AAPL', 120, 145.00, 175.00, 'Information Technology'),
    ('INV002', 'TSLA', 50, 720.00, 680.00, 'Consumer Discretionary'),
    ('INV003', 'AAPL', 200, 155.00, 185.00, 'Information Technology'),
    ('INV003', 'TSLA', 100, 680.00, 640.00, 'Consumer Discretionary'),
    ('INV003', 'NFLX', 90, 520.00, 510.00, 'Communication Services'),
    ('INV004', 'AAPL', 300, 140.00, 170.00, 'Information Technology'),
    ('INV004', 'TSLA', 200, 690.00, 660.00, 'Consumer Discretionary'),
    ('INV004', 'NVDA', 150, 450.00, 500.00, 'Information Technology'),
    ('INV005', 'AAPL', 250, 160.00, 190.00, 'Information Technology'),
    ('INV005', 'TSLA', 150, 710.00, 670.00, 'Consumer Discretionary'),
    ('INV005', 'AMD', 180, 95.00, 105.00, 'Information Technology'),

-- More Data
    ('INV006', 'AAPL', 150, 155.00, 145.00, 'Information Technology'),
    ('INV006', 'TSLA', 100, 690.00, 650.00, 'Consumer Discretionary'),
    ('INV006', 'NVDA', 80, 500.00, 470.00, 'Information Technology'),
    ('INV007', 'AMD', 120, 110.00, 100.00, 'Information Technology'),
    ('INV007', 'GOOG', 90, 2900.00, 2800.00, 'Communication Services'),

    ('INV008', 'JPM', 200, 140.00, 150.00, 'Financials'),
    ('INV008', 'BAC', 300, 38.00, 42.00, 'Financials'),
    ('INV009', 'GS', 120, 340.00, 360.00, 'Financials'),
    ('INV009', 'WFC', 180, 45.00, 50.00, 'Financials'),

    ('INV010', 'TLT', 100, 150.00, 140.00, 'Fixed Income'),
    ('INV010', 'LQD', 80, 120.00, 110.00, 'Fixed Income'),

    ('INV011', 'VNQ', 200, 90.00, 85.00, 'Real Estate'),
    ('INV011', 'AMT', 150, 280.00, 260.00, 'Real Estate'),

    ('INV012', 'AAPL', 150, 160.00, 170.00, 'Information Technology'),
    ('INV012', 'MSFT', 100, 290.00, 310.00, 'Information Technology'),
    ('INV012', 'NVDA', 80, 480.00, 500.00, 'Information Technology'),
    ('INV013', 'AMD', 120, 100.00, 110.00, 'Information Technology'),

    ('INV014', 'JNJ', 200, 160.00, 165.00, 'Health Care'),
    ('INV014', 'PFE', 300, 40.00, 42.00, 'Health Care'),
    ('INV015', 'MRNA', 100, 150.00, 155.00, 'Health Care'),
    ('INV015', 'UNH', 90, 480.00, 500.00, 'Health Care'),

    ('INV016', 'JPM', 250, 145.00, 155.00, 'Financials'),
    ('INV016', 'BAC', 350, 36.00, 40.00, 'Financials'),
    ('INV017', 'GS', 150, 330.00, 350.00, 'Financials'),
    ('INV017', 'WFC', 200, 42.00, 47.00, 'Financials'),

    ('INV018', 'TSLA', 180, 720.00, 750.00, 'Consumer Discretionary'),
    ('INV018', 'AMZN', 200, 3200.00, 3300.00, 'Consumer Discretionary'),
    ('INV019', 'NKE', 160, 120.00, 125.00, 'Consumer Discretionary'),
    ('INV019', 'HD', 140, 300.00, 310.00, 'Consumer Discretionary'),

    ('INV020', 'GOOGL', 110, 2800.00, 2850.00, 'Communication Services'),
    ('INV020', 'NFLX', 130, 500.00, 510.00, 'Communication Services'),
    ('INV021', 'DIS', 170, 150.00, 155.00, 'Communication Services'),
    ('INV021', 'TMUS', 120, 140.00, 145.00, 'Communication Services'),

    ('INV022', 'BA', 180, 220.00, 230.00, 'Industrials'),
    ('INV022', 'GE', 250, 90.00, 95.00, 'Industrials'),
    ('INV023', 'CAT', 140, 210.00, 215.00, 'Industrials'),
    ('INV023', 'UPS', 160, 180.00, 185.00, 'Industrials'),

    ('INV024', 'PG', 200, 140.00, 145.00, 'Consumer Staples'),
    ('INV024', 'KO', 300, 55.00, 58.00, 'Consumer Staples'),
    ('INV025', 'PEP', 250, 160.00, 165.00, 'Consumer Staples'),
    ('INV025', 'WMT', 280, 145.00, 150.00, 'Consumer Staples'),

    ('INV026', 'XOM', 220, 80.00, 85.00, 'Energy'),
    ('INV026', 'CVX', 180, 110.00, 115.00, 'Energy'),
    ('INV027', 'COP', 140, 95.00, 100.00, 'Energy'),
    ('INV027', 'SLB', 200, 60.00, 65.00, 'Energy'),

    ('INV028', 'NEE', 250, 75.00, 78.00, 'Utilities'),
    ('INV028', 'DUK', 200, 95.00, 98.00, 'Utilities'),
    ('INV029', 'SO', 300, 70.00, 72.00, 'Utilities'),
    ('INV029', 'XEL', 150, 65.00, 67.00, 'Utilities'),

    ('INV030', 'VNQ', 280, 88.00, 92.00, 'Real Estate'),
    ('INV030', 'AMT', 180, 270.00, 280.00, 'Real Estate'),
    ('INV031', 'SPG', 160, 120.00, 125.00, 'Real Estate'),
    ('INV031', 'PLD', 200, 140.00, 145.00, 'Real Estate'),

    ('INV032', 'LIN', 150, 300.00, 310.00, 'Materials'),
    ('INV032', 'SHW', 180, 270.00, 280.00, 'Materials'),
    ('INV033', 'FCX', 200, 35.00, 38.00, 'Materials'),
    ('INV033', 'NEM', 140, 50.00, 53.00, 'Materials');


    

