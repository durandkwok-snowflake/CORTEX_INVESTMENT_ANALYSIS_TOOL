# Financial News Research & Portfolio Analysis with Snowflake Cortex

## Overview
This project demonstrates how to leverage **Snowflake Cortex Search** for financial news research and **Snowflake Cortex Analyst** for portfolio risk analysis. By integrating AI-driven insights, investors can gain a deeper understanding of market trends and make data-driven investment decisions.

## Features
- **Financial News Research**: Use **Snowflake Cortex Search** to extract relevant financial articles and reports.
- **Portfolio Risk Analysis**: Apply **Snowflake Cortex Analyst** to assess sentiment and classify risk levels.
- **Automated Insights**: AI-powered analysis to support investment decisions.
- **Streamlit Dashboard (Optional)**: Visualize financial insights interactively.

## Setup Instructions
### 1. Prerequisites
- **Snowflake Account** with **Cortex Search & Analyst** enabled.
- **Python 3.8+** (for optional dashboard visualization).
- **Financial Data** (e.g., portfolio holdings, news sources).

### 2. Setting Up the Environment
```sql
-- Enable Snowflake Cortex
USE ROLE ACCOUNTADMIN;
ALTER ACCOUNT SET ENABLE_CORTEX = TRUE;
```

If using Python:
```bash
conda create -n cortex_finance python=3.8
conda activate cortex_finance
pip install streamlit snowflake-connector-python
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

## Optional: Running the Streamlit Dashboard
If you want to visualize insights interactively:
```bash
streamlit run streamlit_app.py
```

## Future Enhancements
- Incorporate real-time stock market APIs.
- Expand AI models for more granular risk assessment.
- Automate financial news aggregation for portfolio insights.

## Contributors
- [Your Name]
- [Your Team]

## License
This project is licensed under the MIT License. See `LICENSE` for details.

