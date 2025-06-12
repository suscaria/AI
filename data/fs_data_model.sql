--1. Country Dimension Table

CREATE TABLE dim_country (
    country_id INT PRIMARY KEY,
    country_name VARCHAR(100) NOT NULL,
    region VARCHAR(50),
    continent VARCHAR(30)
);


-- 2. Customer Dimension Table

CREATE TABLE dim_customer (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    city VARCHAR(100),
    state VARCHAR(100),
    country_id INT,
    email VARCHAR(150),
    phone VARCHAR(20),
    registration_date DATE,
    FOREIGN KEY (country_id) REFERENCES dim_country(country_id)
);

--3. dim_time
CREATE TABLE dim_time (
    date_key INT PRIMARY KEY,
    full_date DATE NOT NULL,
    year INT,
    quarter INT,
    quarter_name VARCHAR(10),
    month INT,
    month_name VARCHAR(20),
    week_of_year INT,
    week_start_date DATE,
    week_end_date DATE,
    day_of_week INT,
    day_name VARCHAR(10),
    is_weekend BOOLEAN
);

--4. Apple Store Dimension Table

CREATE TABLE dim_apple_store (
    store_id INT PRIMARY KEY,
    store_name VARCHAR(100) NOT NULL,
    store_type VARCHAR(50),
    address VARCHAR(200),
    city VARCHAR(100),
    state VARCHAR(100),
    country_id INT,
    phone VARCHAR(20),
    opening_date DATE,
    store_size_sqft INT,
    FOREIGN KEY (country_id) REFERENCES dim_country(country_id)
);


--5. Sales Fact Table


CREATE TABLE fact_sales (
    sales_id INT PRIMARY KEY,
    customer_id INT,
    store_id INT,
    country_id INT,
    date_key INT,
    product_name VARCHAR(100),
    product_category VARCHAR(50),
    quantity INT,
    unit_price DECIMAL(10,2),
    total_amount DECIMAL(12,2),
    discount_amount DECIMAL(10,2),
    tax_amount DECIMAL(10,2),
    FOREIGN KEY (customer_id) REFERENCES dim_customer(customer_id),
    FOREIGN KEY (store_id) REFERENCES dim_apple_store(store_id),
    FOREIGN KEY (country_id) REFERENCES dim_country(country_id),
    FOREIGN KEY (date_key) REFERENCES dim_time(date_key)
);

--6. AppleCare Requests Table

CREATE TABLE applecare_requests (
    request_id INT PRIMARY KEY,
    customer_id INT,
    product_name VARCHAR(100),
    product_category VARCHAR(50),
    issue_category VARCHAR(100),
    issue_description TEXT,
    request_date DATE,
    status VARCHAR(50),
    resolution_date DATE,
    priority VARCHAR(20),
    assigned_technician VARCHAR(100),
    FOREIGN KEY (customer_id) REFERENCES dim_customer(customer_id)
);


--7. Campaign Table



CREATE TABLE dim_campaign (
    campaign_id INT PRIMARY KEY,
    customer_id INT,
    campaign_name VARCHAR(100),
    campaign_type VARCHAR(50),
    start_date DATE,
    end_date DATE,
    channel VARCHAR(50),
    budget DECIMAL(12,2),
    target_audience VARCHAR(100),
    campaign_status VARCHAR(20),
    FOREIGN KEY (customer_id) REFERENCES dim_customer(customer_id)
);

## Data Loading Instructions

-- 1. Create Database and Schema

-- Create database
CREATE DATABASE apple_store_analytics;
USE apple_store_analytics;

-- Create schema for better organization
CREATE SCHEMA IF NOT EXISTS retail;
USE SCHEMA retail;


--### 2. Load Data in Sequence (Respect Foreign Key Dependencies)

-- Load dimension tables first
-- 1. Country dimension (no dependencies)
COPY INTO dim_country FROM @docs_ss/dim_country.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_DELIMITER = ',' SKIP_HEADER = 1);

-- 2. Customer dimension (depends on country)
COPY INTO dim_customer FROM @docs_ss/dim_customer.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_DELIMITER = ',' SKIP_HEADER = 1);

-- 3. Time dimension (no dependencies)
COPY INTO dim_time FROM @docs_ss/dim_time.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_DELIMITER = ',' SKIP_HEADER = 1);

-- 4. Apple Store dimension (depends on country)
COPY INTO dim_apple_store FROM @docs_ss/dim_apple_store.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_DELIMITER = ',' SKIP_HEADER = 1);

-- Load fact and transaction tables
-- 5. Sales fact table (depends on all dimensions)
COPY INTO fact_sales FROM @docs_ss/fact_sales.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_DELIMITER = ',' SKIP_HEADER = 1);

-- 6. AppleCare requests (depends on customer)
COPY INTO applecare_requests FROM @docs_ss/applecare_requests.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_DELIMITER = ',' SKIP_HEADER = 1);

-- 7. Campaign dimension (depends on customer)
COPY INTO dim_campaign FROM @docs_ss/dim_campaign.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_DELIMITER = ',' SKIP_HEADER = 1);


-- Sample Analytical Queries for Demo

--1. Sales Performance by Quarter
sql
SELECT 
    t.year,
    t.quarter_name,
    COUNT(s.sales_id) as total_sales,
    SUM(s.total_amount) as total_revenue,
    AVG(s.total_amount) as avg_order_value
FROM fact_sales s
JOIN dim_time t ON s.date_key = t.date_key
GROUP BY t.year, t.quarter, t.quarter_name
ORDER BY t.year, t.quarter;


--2. Top Performing Stores by Country

SELECT 
    c.country_name,
    st.store_name,
    COUNT(s.sales_id) as total_transactions,
    SUM(s.total_amount) as total_revenue
FROM fact_sales s
JOIN dim_apple_store st ON s.store_id = st.store_id
JOIN dim_country c ON st.country_id = c.country_id
GROUP BY c.country_name, st.store_name
ORDER BY total_revenue DESC
LIMIT 10;


-- 3. AppleCare Requests Analysis

SELECT 
    product_category,
    issue_category,
    COUNT(*) as request_count,
    AVG(DATEDIFF(day, request_date, resolution_date)) as avg_resolution_days
FROM applecare_requests
WHERE status = 'Resolved'
GROUP BY product_category, issue_category
ORDER BY request_count DESC;


--### 4. Campaign Effectiveness

SELECT 
    camp.campaign_name,
    camp.campaign_type,
    COUNT(DISTINCT camp.customer_id) as customers_targeted,
    COUNT(s.sales_id) as resulting_sales,
    SUM(s.total_amount) as campaign_revenue,
    camp.budget,
    (SUM(s.total_amount) - camp.budget) as roi
FROM dim_campaign camp
LEFT JOIN fact_sales s ON camp.customer_id = s.customer_id 
    AND s.date_key BETWEEN REPLACE(camp.start_date, '-', '') AND REPLACE(camp.end_date, '-', '')
GROUP BY camp.campaign_name, camp.campaign_type, camp.budget
ORDER BY roi DESC;


---## Key Features of This Data Model
---
---1. **Comprehensive Relationships**: All tables are properly connected with foreign keys
---2. **Realistic Data**: Sample data reflects real-world Apple Store scenarios
---3. **Time Intelligence**: Weekly and quarterly reporting capabilities built-in
---4. **Global Coverage**: 100 countries with regional groupings
---5. **Product Diversity**: Full range of Apple products represented
---6. **Customer Journey**: From campaigns to sales to support requests
---7. **Scalable Design**: Easy to add more data while maintaining relationships
---8. **Demo-Ready**: Sufficient data volume for meaningful analytics and joins
---
---This data model provides a solid foundation for demonstrating various analytical scenarios including sales performance, customer behavior, support patterns, and marketing campaign effectiveness.