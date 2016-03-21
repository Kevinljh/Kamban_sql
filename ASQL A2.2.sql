--CREATE DATABASE "Kanban ERD"
--USE "Kanban ERD"

--drop table StationItem;
--drop table LogResult;
--drop table Parts;
--drop table Worker;
--drop table Lamps;
--drop table Station;


CREATE TABLE Parts
(
	PID varchar(10) NOT NULL PRIMARY KEY,
	Name varchar(30),
	Increasement int 
);

CREATE TABLE Station
(
	SID varchar(10) NOT NULL PRIMARY KEY
);

CREATE TABLE StationItem
(
	SID varchar(10) FOREIGN KEY REFERENCES Station(SID), 
	PID varchar(10) FOREIGN KEY REFERENCES Parts(PID),
	Stock_Level int,
	-- 0. stock level greater than 5
	-- 1. stock level less than 5
	-- 2. wait 5 min for new parts
	Request_Flag int default 0,
	PRIMARY KEY ( SID, PID)
);

CREATE TABLE Worker
(
	WID varchar(10) NOT NULL PRIMARY KEY,
	Defect_Rate float,
	Experience varchar(20),
	SID varchar(10) FOREIGN KEY(SID) REFERENCES Station(SID)
);


CREATE TABLE Lamps
(
	Serial_No varchar(20) NOT NULL PRIMARY KEY,
	Tray_No int,
	Defective Bit,
	SID varchar(10) FOREIGN KEY REFERENCES Station(SID),
	[Time] varchar(50)
);

CREATE TABLE LogResult
(
	LogID int NOT NULL IDENTITY(1,1),
	SID varchar(10) FOREIGN KEY(SID) REFERENCES Station(SID),
	PID varchar(10) FOREIGN KEY(PID) REFERENCES Parts(PID),
	[Time] varchar(50),
	Remains int
);


INSERT INTO Station VALUES 
('1'),
('2'),
('3')

INSERT INTO Parts VALUES 
('1', 'Harness', 55),
('2', 'Reflector', 35),
('3', 'Housing', 24),
('4', 'Lens', 40),
('5', 'Bulb', 60),
('6', 'Bezel', 75)

INSERT INTO Worker VALUES 
('1', 0.0058, 'New', '1'),
('2', 0.005, 'Experienced', '2'),
('3', 0.0015, 'VExperience', '3')



--This procedure takes three parameters - "TrayNo" is the tray number for each station. 
--"ItemNo" is the position in the tray. "StationID" indicates which station makes this lamp.
--Makelamp is called to insert lamp datas into table each time a lamp is finished. It takes
--tray number and item number to generate a test unit number for each lamp. First I check how 
--many place holder the tray number and item number has, so that I can know how many "0"s I 
--should pad to the begining.

--drop PROCEDURE MakeLamp;
GO

CREATE PROCEDURE MakeLamp(@trayNo varchar(10), @itemNo varchar(10), @stationID varchar(10))
AS
	DECLARE @part_inc INT
	DECLARE @mySid VARCHAR(10)
	DECLARE part_cursor CURSOR  For SELECT  StationItem.Stock_Level FROM StationItem
	WHERE @stationID = StationItem.SID
	OPEN part_cursor
    FETCH NEXT FROM product_cursor INTO @part_inc
	WHILE @@FETCH_STATUS = 0
		BEGIN
			IF(@part_inc > 0)
				DECLARE @SerialNo varchar(20)
				SELECT @trayNo = REPLICATE('0', 6-LEN(@trayNo)) + @trayNo
				SELECT @itemNo = REPLICATE('0', 2-LEN(@itemNo)) + @itemNo
				SELECT @SerialNo = CONCAT( 'FL', @trayNo, @itemNo)
				INSERT INTO Lamps (Serial_No, Tray_No, Defective, SID, [Time]) Values (@SerialNo, @trayNo, 0, @stationID, GETDATE())
		END
	CLOSE part_cursor
GO

--This procedure is used to log data during the work time. It would be called when the work station's tray 
--is upadated (after runner bring the specific parts to the station). The station's id, total remainning parts, 
--and current time would be writing to the LogResult table for future use.

--drop PROCEDURE LogData;

CREATE PROCEDURE LogData(@sid varchar(10), @pid varchar(10), @remains int)
AS
	INSERT INTO LogResult(SID, PID, [Time], Remains) Values (@sid, @pid, GETDATE(), @remains)

GO

--This procedure is used to insert a set of data to StationItem when a station starts working.
--The amount of data are being inserted is according to the Parts table. The cursor is used to 
--create a item for each parts. 

CREATE PROCEDURE InitialStationItem(@sid varchar(10))
AS 
	DECLARE @part_inc INT
	DECLARE @part_id VARCHAR(10)
	DECLARE part_cursor CURSOR  For SELECT  Parts.Increasement, Parts.PID FROM PARTS
	OPEN part_cursor
    FETCH NEXT FROM product_cursor INTO @part_inc, @part_id
	WHILE @@FETCH_STATUS = 0
		BEGIN
			INSERT INTO StationItem (SID, PID, Stock_Level) VALUES (@sid, @part_id, @part_inc)
		END
	CLOSE part_cursor

GO

--TragAfterLampInsert tragger is used to update the StationItem when a new 
--is maked (after new row is inserted into Lamps).
--It will decrease every part's stock level by 1 for the specific station. 

--drop trigger tragAfterLampInsert;

CREATE TRIGGER tragAfterLampInsert ON Lamps
FOR INSERT
AS
	DECLARE @lampSid varchar(10)
	SELECT @lampSid = i.SID FROM inserted i
	UPDATE StationItem 
	SET Stock_Level -= 1
	WHERE @lampSid = StationItem.SID

GO

--TragAfterUpdateStockLeve is used to change the Request_Flag in StationItem table. 
--It check the stock level for each part in this station, if the stock level is equal
--to 5, the Request_Flag will be set to 1, which means the runner need to refill the bin.
--When stock level is smaller the 5, it set the flag back to 0.

--drop trigger tragAfterUpdateStockLeve;

CREATE TRIGGER tragAfterUpdateStockLeve ON StationItem
FOR UPDATE
AS
	DECLARE @stockLevel varchar(10)
	DECLARE @pid varchar(10)
	DECLARE @sid varchar(10)
	SELECT @sid = i.SID FROM inserted i
	SELECT @stockLevel = i.Stock_Level FROM inserted i
	SELECT @pid = i.PID FROM inserted i
	IF(@stockLevel=5)
		UPDATE StationItem
		SET Request_Flag = 1
		WHERE StationItem.SID = @sid and StationItem.PID = @pid
	IF(@stockLevel>5)
		UPDATE StationItem
		SET Request_Flag = 0
		WHERE StationItem.SID = @sid and StationItem.PID = @pid

GO

