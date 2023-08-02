
SELECT * FROM dbo.DeliveryData;


-- Shows all columns but with distinct company names
SELECT 
    MAX(PrimaryKey) AS PrimaryKey,
    MAX(Company_ID) AS Company_ID,
    Company_Name,
    MAX(Origin_Coordinates) AS Origin_Coordinates,
    MAX(Cost_Per_Minute) AS Cost_Per_Minute,
    MAX(Estimated_Trips_Per_Month) AS Estimated_Trips_Per_Month,
    MAX(Date) AS Date,
    MAX(Destination_Coordinates) AS Destination_Coordinates
FROM dbo.DeliveryData
GROUP BY Company_Name
ORDER BY MAX(Company_ID) ASC;


-- Creates role that has permisions to only run stored procedures, then grants executes permision
CREATE ROLE dbProcedureAccessOnly;

GRANT EXECUTE TO dbProcedureAccessOnly;


-- Creates procedure that selects all values from Employee_Master table
CREATE PROCEDURE dbo.spDelivery_Data_GetAll
AS
BEGIN
    SELECT * FROM dbo.DeliveryData;
END


-- Executes procedure
EXEC dbo.spDelivery_Data_GetAll;


-- Creates a copy of the PrimaryKey column from dbo.DeliveryData as DeliveryData_Totals
SELECT PrimaryKey
INTO dbo.DeliveryData_Totals
FROM dbo.DeliveryData
WHERE 1 = 0 

INSERT INTO dbo.DeliveryData_Totals (PrimaryKey)
SELECT PrimaryKey
FROM dbo.DeliveryData;


-- Adds new columns that were created in Python
ALTER TABLE dbo.DeliveryData_Totals
ADD Estimated_Travel_Time FLOAT,
    Total_Time_In_Minutes FLOAT,
    Total_Cost MONEY;


-- Verify that new columns and table was made
SELECT * FROM dbo.DeliveryData_Totals;


-- Creates procedure that Python will use to export the DataFrame into the new table
CREATE PROCEDURE dbo.spInsert_Delivery_Data
    @Data XML
AS
BEGIN
    SET NOCOUNT ON;

    MERGE dbo.DeliveryData_Totals AS target
    USING (
        SELECT
            r.value('PrimaryKey[1]', 'TINYINT') AS PrimaryKey,
			r.value('Estimated_Travel_Time[1]', 'FLOAT') AS Estimated_Travel_Time,
            r.value('Total_Time_In_Minutes[1]', 'FLOAT') AS Total_Time_In_Minutes,
            r.value('Total_Cost[1]', 'MONEY') AS Total_Cost
        FROM @Data.nodes('/root/row') AS t(r)
    ) AS source
    ON target.PrimaryKey = source.PrimaryKey
    WHEN MATCHED THEN
        UPDATE SET
			target.PrimaryKey = source.PrimaryKey,
            target.Estimated_Travel_Time = source.Estimated_Travel_Time,
            target.Total_Time_In_Minutes = source.Total_Time_In_Minutes,
            target.Total_Cost = source.Total_Cost
    WHEN NOT MATCHED THEN
        INSERT (
            PrimaryKey, Estimated_Travel_Time, Total_Time_In_Minutes, Total_Cost
        )
        VALUES (
            source.PrimaryKey, source.Estimated_Travel_Time,
            source.Total_Time_In_Minutes, source.Total_Cost
        );
END;


-- Verify that data was imported properly from Python
SELECT * FROM dbo.DeliveryData_Totals;


-- Views the joined view from both tables
SELECT dt.PrimaryKey, dt.Company_ID, dt.Company_Name, 
	   dt.Origin_Coordinates, dt.Cost_Per_Minute, 
	   dt.Estimated_Trips_Per_Month, dt.Date, 
	   dt.Destination_Coordinates, dd.Estimated_Travel_Time, 
	   dd.Total_Time_In_Minutes, dd.Total_Cost
FROM dbo.DeliveryData AS dt
JOIN dbo.DeliveryData_Totals AS dd ON dt.PrimaryKey = dd.PrimaryKey;
