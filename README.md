# Financial News Research & Portfolio Analysis with Snowflake Cortex Search and Cortex Analyst

## Overview
This project demonstrates how to leverage **Snowflake Cortex Search** for financial news research and **Snowflake Cortex Analyst** for portfolio risk analysis. By integrating AI-driven insights, investors can gain a deeper understanding of market trends and make data-driven investment decisions.

## Features
- **Financial News Research**: Use **Snowflake Cortex Search** to extract relevant financial articles and reports.
- **Portfolio Risk Analysis**: Apply **Snowflake Cortex Analyst** to assess sentiment and classify risk levels.
- **Streamlit Dashboard**: Find financial insights interactively.


![image](https://github.com/user-attachments/assets/a9d73f0b-a8cb-47cc-b167-55b7c462fbbb)


## Setup Instructions
### 1. Prerequisites
- **Snowflake Account** with **Cortex Search & Analyst** enabled.
- **Financial Data** (e.g., portfolio holdings, news sources).

### 2. Setting Up the Environment
```sql
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



```


## Using Snowflake Cortex
### 1. Researching Financial News with Cortex Search
Snowflake Cortex Search allows users to retrieve the most relevant financial news articles based on a query.
Start by creaating the Streamlit App in Snowflake.

![image](https://github.com/user-attachments/assets/48c87ce8-9883-43e7-aa3d-e26ef543754a)

![image](https://github.com/user-attachments/assets/dba295b8-c41b-4c96-af66-dd89422144b3)

Once the Streamlit App is created, it also creates an internal stage that contains the stream_app.py and the environment.yml files
![image](https://github.com/user-attachments/assets/60bd61af-4301-48e7-8fda-be853ded627c)


The following streamlit_app.py and the environment.yml file are Streamlit Application files. The py file contains python code that sets up Cortex Search as well as Cortex Analyst.
Upload and replace with the streamlit_app.py and the environment.yml files from this github to stage of your Streamlit in Snowflake application.

![image](https://github.com/user-attachments/assets/fcd8a2a2-c995-403d-a854-b220248f60e9)


### 2. Analyzing Portfolio Risk with Cortex Analyst
Snowflake Cortex Analyst processes textual financial data to classify sentiment and risk factors.
Upload the investment_analyst.yaml file to @docs internal stage.
The investment_analyst.yaml file is the Semantic Model that is needed for Cortex Analyst to talk to your structure portfolio data

![image](https://github.com/user-attachments/assets/92eb6a47-7585-4813-92a7-b49bc65b366a)

### 3. Starting Investment_Cortex Streamlit App in Snowflake
**Starting the Streamlit App**

![image](https://github.com/user-attachments/assets/1f534501-dab8-41af-b121-61d38e124fb4)

**Select the LLM that you want to use**

![image](https://github.com/user-attachments/assets/7c763517-f683-47de-84e0-0387b9aef6af)


**Then select from the list of Financial News document to research.**

![image](https://github.com/user-attachments/assets/1240eea7-0e99-4c7f-a1b2-90c1b375c6bc)


**Type in your question(s) in the text box.**

![image](https://github.com/user-attachments/assets/de7921bb-c714-4ce4-acd1-e7e000f17367)

**Then use Cortex Analyst to perform analysis on your structured data by typing in your question in the texts box**

![image](https://github.com/user-attachments/assets/b6af641b-da85-4314-a87a-73539b91f7b4)

### 4. Example:
**Start with Financial News Research**

I)
![image](https://github.com/user-attachments/assets/012aa5bc-6f03-44be-9113-f3615ea7bfab)

II)
![image](https://github.com/user-attachments/assets/2031d3af-f033-4141-976f-b8625539c169)

**Also you can experiment with different models:**

![image](https://github.com/user-attachments/assets/96c79c9c-3200-4d8f-97b0-bc4b4b2beaac)


**Then Continue on with Portfolio Analysis**

![image](https://github.com/user-attachments/assets/75af07ff-f60b-40f4-965c-23913950a2c1)

![image](https://github.com/user-attachments/assets/5125e256-3e43-4e45-915d-cbcd2d8c2ca5)

