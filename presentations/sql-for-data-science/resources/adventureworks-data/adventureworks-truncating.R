# original data is from https://github.com/infinuendo/AdventureWorks/tree/master/OLTP/Original

library(tidyverse)
library(lubridate)
library(odbc)

# product ----------------------------------------------------------------------
product <- read_tsv('./presentations/sql-for-data-science/resources/adventureworks-data/product.tsv',
                    col_types = cols(),
                    col_names=c('ProductID'
                                ,'Name'
                                ,'ProductNumber'
                                ,'MakeFlag'
                                ,'FinishedGoodsFlag'
                                ,'Color'
                                ,'SafetyStockLevel'
                                ,'ReorderPoint'
                                ,'StandardCost'
                                ,'ListPrice'
                                ,'Size'
                                ,'SizeUnitMeasureCode'
                                ,'WeightUnitMeasureCode'
                                ,'Weight'
                                ,'DaysToManufacture'
                                ,'ProductLine'
                                ,'Class'
                                ,'Style'
                                ,'ProductSubcategoryID'
                                ,'ProductModelID'
                                ,'SellStartDate'
                                ,'SellEndDate'
                                ,'DiscontinuedDate'
                                ,'rowguid'
                                ,'ModifiedDate')
                    )
product <- product %>% 
  mutate_at(c('ProductID','MakeFlag', 
              'ProductSubcategoryID','ProductModelID'), as.integer) %>%
  rename_all(tolower) %>% 
  mutate(discontinueddate = as_datetime(discontinueddate)) %>%
  mutate(sellstartdate = sellstartdate + dyears(13), 
         sellenddate = sellenddate + dyears(13), 
         discontinueddate = discontinueddate + dyears(13), 
         modifieddate = modifieddate + dyears(13))

# productcategory --------------------------------------------------------------
productcategory <- read_tsv('./presentations/sql-for-data-science/resources/adventureworks-data/productcategory.tsv',
                            col_types = cols(),
                            col_names=c('ProductCategoryID', 
                                        'Name',
                                        'rowguid',
                                        'ModifiedDate')
                            )
productcategory <- productcategory %>% 
  mutate_at(c('ProductCategoryID'), as.integer) %>%
  rename_all(tolower) %>% 
  mutate(modifieddate = modifieddate + dyears(19))

# transactionhistory -----------------------------------------------------------
transactionhistory <- read_tsv('./presentations/sql-for-data-science/resources/adventureworks-data/transactionhistory.tsv',
                               col_types = cols(),
                               col_names=c('TransactionID'
                                          ,'ProductID'
                                          ,'ReferenceOrderID'
                                          ,'ReferenceOrderLineID'
                                          ,'TransactionDate'
                                          ,'TransactionType'
                                          ,'Quantity'
                                          ,'ActualCost'
                                          ,'ModifiedDate')
                               )
# downsample transactionhistory because the Heroku free tier row limit is 10K
transactionhistory <- transactionhistory %>% 
  mutate_at(c('TransactionID', 'ProductID', 
              'ReferenceOrderID', 'ReferenceOrderLineID'), as.integer) %>%
  rename_all(tolower) %>% 
  mutate(transactiondate = transactiondate + dyears(13), 
         modifieddate = modifieddate + dyears(13)) %>% 
  filter(year(transactiondate) == 2017, month(transactiondate) <= 6) %>%
  mutate(month = format(transactiondate, '%Y-%m')) %>%
  group_by(month) %>%
  sample_n(1000) %>% 
  ungroup() %>%
  select(-month)

# push tables to Postgres ------------------------------------------------------

pg_conn <- function(){
  dbConnect(drv=RPostgreSQL::PostgreSQL(), 
            host='ec2-107-22-169-45.compute-1.amazonaws.com',
            dbname='d54sjlbs6erhjs',
            port=5432,
            user='rmfenpdczlrtqo',
            password='57a3df647d21f42d4dc029cd951ac7762e1ad440e411dfc8fb7dffb57d82d976')
}

con <- pg_conn()
dbWriteTable(con, "product", as.data.frame(product), row.names=FALSE)
dbWriteTable(con, "productcategory", as.data.frame(productcategory), row.names=FALSE)
dbWriteTable(con, "transactionhistory", as.data.frame(transactionhistory), row.names=FALSE)

# # drop tables if you need to push them again
# dbGetQuery(con, "DROP TABLE product")
# dbGetQuery(con, "DROP TABLE productcategory")
# dbGetQuery(con, "DROP TABLE transactionhistory")

dbDisconnect(con)

# check that the tables made it
con <- pg_conn()
product_check <- dbGetQuery(con, "SELECT * FROM product")
