# Financial News Research & Portfolio Analysis with Snowflake Cortex

## Overview
This project demonstrates how to leverage **Snowflake Cortex Search** for financial news research and **Snowflake Cortex Analyst** for portfolio risk analysis. By integrating AI-driven insights, investors can gain a deeper understanding of market trends and make data-driven investment decisions.

## Features
- **Financial News Research**: Use **Snowflake Cortex Search** to extract relevant financial articles and reports.
- **Portfolio Risk Analysis**: Apply **Snowflake Cortex Analyst** to assess sentiment and classify risk levels.
- **Streamlit Dashboard**: Visualize financial insights interactively.

## Setup Instructions
### 1. Prerequisites
- **Snowflake Account** with **Cortex Search & Analyst** enabled.
- **Financial Data** (e.g., portfolio holdings, news sources).

### 2. Setting Up the Environment
```sql
-- Enable Snowflake Cortex
USE ROLE ACCOUNTADMIN;
ALTER ACCOUNT SET ENABLE_CORTEX = TRUE;
```


## Using Snowflake Cortex
### 1. Researching Financial News with Cortex Search
Snowflake Cortex Search allows users to retrieve the most relevant financial news articles based on a query.

**Example Query:**
```sql
SELECT * FROM TABLE(CORTEX_SEARCH(
    'financial_news_dataset', 'Federal Reserve interest rate policy impact'
));
```
This query fetches news articles related to **Federal Reserve interest rate changes** and their effect on the market.

### 2. Analyzing Portfolio Risk with Cortex Analyst
Snowflake Cortex Analyst processes textual financial data to classify sentiment and risk factors.

**Example Query:**
```sql
SELECT stock_symbol, CORTEX_ANALYST(sentiment, risk_classification)
FROM portfolio_holdings;
```
This query analyzes the **sentiment and risk classification** for each stock in a portfolio.





