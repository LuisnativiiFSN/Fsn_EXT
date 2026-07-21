/// <summary>
/// Codeunit FSN Replication server (ID 50017).
/// </summary>
codeunit 50017 "FSN Replication server"
{
    SingleInstance = true;

    trigger OnRun()
    begin
        ReplicationVerify();
        AppsList();
    end;
    #region [variables]
    var
        Location: Record "LSC Distribution Location";
        RetailSetup: Record "LSC Retail Setup";
        Undefined: Label 'Undefined';
    #endregion
    #region [Procedures]
    procedure ReplicationVerify()
    var
        Text000: Label 'Nº de Tienda: %1 ,Terminal: %2, Fecha: %3, Hora: %4 Insertados';
        Text001: Label 'Nº de Tienda: %1 ,Terminal: %2, Fecha: %3, Hora: %4 ya existe';
        Fecha: Date;
        Hora: Time;
        fechaHora: DateTime;
        RepVerify: Record "FSN Replication Verify";  //"50003";
        SqlConnection: DotNet SqlConnection;
        SqlCommand: DotNet SqlCommand;
        SqlDataReader: DotNet SqlDataReader;
        connString: Text;
        myVar: Text;
        SQLstring: Text;
        Unidad: Text;
        Espacio: Decimal;
        Ip: Text;
        DB_ID: Integer;
        query1: Text;
        query2: Text;
        ValueD: Decimal;

    begin
        //FSNFRODRIGUEZ22ENE2019
        Fecha := TODAY;
        Hora := TIME;
        fechaHora := CURRENTDATETIME;
        connString := GetconString();
        if connString = Undefined then
            exit;

        query1 := 'use master CREATE TABLE #Temp1 (drive varchar(5),[MB] decimal) INSERT INTO #Temp1 EXEC XP_FIXEDDRIVES CREATE TABLE #Temp2 (IP varchar(max)) INSERT INTO #Temp2 EXEC master..xp_cmdshell ''ipconfig'' select substring(t2.IP,CHARINDEX('':'',t2.IP,1)+2,LEN(t2.IP)-(CHARINDEX('':'',t2.IP,1)+1)) as local_net_address,t1.drive,t1.[MB]from  #Temp1 t1 join  #Temp2 t2 on t2.IP like ''%IPv4%'' and  t1.drive=''C''';
        query2 := 'SELECT [database_id],[Database_Name],[Drive_Letter],[Drive_Label],[Total_Size_MB],[Free_Space_MB],[Total_Size_GB],[Free_Space_GB],[Free_Space_Percentage],[Used_Space_Percentage],[DB_Log_MB],[DB_Data_MB],[DB_Log_GB],[DB_Data_GB] FROM [master].[dbo].[Volume Stats View]';
        SqlConnection := SqlConnection.SqlConnection(connString);
        SqlConnection.Open();
        SqlCommand := SqlConnection.CreateCommand();
        SqlCommand.CommandText := query1;
        SqlDataReader := SqlCommand.ExecuteReader();


        WHILE SqlDataReader.Read() DO BEGIN
            Unidad := SqlDataReader.Item('drive');
            Espacio := SqlDataReader.Item('MB');
            Espacio := ROUND(Espacio / 1024, 0.01, '=');
            Ip := SqlDataReader.Item('local_net_address');
        END;

        SQLstring := 'IF OBJECT_ID (''tempdb..#Temp1'') IS NOT NULL DROP TABLE #Temp1';
        SqlCommand.CommandText := SQLstring;
        SQLstring := 'IF OBJECT_ID (''tempdb..#Temp2'') IS NOT NULL DROP TABLE #Temp2';
        SqlCommand.CommandText := SQLstring;
        SqlDataReader.Close();

        SqlCommand.CommandText := query2; //get statistics volume and database
        SqlDataReader := SqlCommand.ExecuteReader();
        RepVerify.RESET;
        RepVerify.SETRANGE(DB_Id, 0);
        IF RepVerify.FIND('-') THEN BEGIN
            RepVerify.DELETEALL;
        END;
        RepVerify.RESET;
        RepVerify.SETFILTER(Terminal, '<>%1', RetailSetup."Local Store No.");
        IF RepVerify.FIND('-') THEN BEGIN
            RepVerify.DELETEALL;
        END;
        RepVerify.RESET;

        WHILE SqlDataReader.Read() DO BEGIN
            DB_ID := SqlDataReader.Item('database_id');
            IF RepVerify.GET(RetailSetup."Local Store No.", Location.Code + '-' + Format(SqlDataReader.Item('Drive_Letter')), DB_ID/*SqlDataReader.Item('database_id')*/) THEN BEGIN
                RepVerify.Date := Fecha;
                RepVerify.Time := Hora;
                RepVerify.IpAddress := Ip;
                RepVerify.DriveLetter := SqlDataReader.Item('Drive_Letter');
                RepVerify.DriveSpace := Espacio;
                RepVerify.DB_Name := SqlDataReader.Item('Database_Name');
                RepVerify.TotalSizeMB := SqlDataReader.Item('Total_Size_MB');
                RepVerify.TotalSizeGB := SqlDataReader.Item('Total_Size_GB');
                RepVerify.FreeSpaceMB := SqlDataReader.Item('Free_Space_MB');
                RepVerify.FreeSpaceGB := SqlDataReader.Item('Free_Space_GB');
                RepVerify.FreeSpacePercentage := SqlDataReader.Item('Free_Space_Percentage');
                RepVerify.UsedSpacePercentage := SqlDataReader.Item('Used_Space_Percentage');
                RepVerify.SizeDB_Log_MB := SqlDataReader.Item('DB_Log_MB');
                RepVerify.SizeDB_LogGB := SqlDataReader.Item('DB_Log_GB');
                RepVerify.SizeDB_DataMB := SqlDataReader.Item('DB_Data_MB');
                RepVerify.SizeDB_DataGB := SqlDataReader.Item('DB_Data_GB');
                RepVerify.MODIFY;
            END
            ELSE BEGIN
                RepVerify.RESET;
                RepVerify.INIT;
                RepVerify.StoreNo := RetailSetup."Local Store No.";
                RepVerify.Terminal := Location."Code" + '-' + Format(SqlDataReader.Item('Drive_Letter'));
                RepVerify.Date := Fecha;
                RepVerify.Time := Hora;
                RepVerify.IpAddress := Ip;
                RepVerify.DriveLetter := SqlDataReader.Item('Drive_Letter');
                RepVerify.DriveSpace := Espacio;
                RepVerify.DB_Id := SqlDataReader.Item('database_id');
                RepVerify.DB_Name := SqlDataReader.Item('Database_Name');
                RepVerify.TotalSizeMB := SqlDataReader.Item('Total_Size_MB');
                RepVerify.TotalSizeGB := SqlDataReader.Item('Total_Size_GB');
                RepVerify.FreeSpaceMB := SqlDataReader.Item('Free_Space_MB');
                RepVerify.FreeSpaceGB := SqlDataReader.Item('Free_Space_GB');
                RepVerify.FreeSpacePercentage := SqlDataReader.Item('Free_Space_Percentage');
                RepVerify.UsedSpacePercentage := SqlDataReader.Item('Used_Space_Percentage');
                RepVerify.SizeDB_Log_MB := SqlDataReader.Item('DB_Log_MB');
                RepVerify.SizeDB_LogGB := SqlDataReader.Item('DB_Log_GB');
                RepVerify.SizeDB_DataMB := SqlDataReader.Item('DB_Data_MB');
                RepVerify.SizeDB_DataGB := SqlDataReader.Item('DB_Data_GB');
                RepVerify.INSERT;

            END;


        END;
        SqlConnection.Close();
        //EJ
    end;

    Procedure AppsList()
    var
        RepVerify: Record "FSN Replication Verify";
        SqlConnection: DotNet SqlConnection;
        SqlCommand: DotNet SqlCommand;
        SqlDataReader: DotNet SqlDataReader;
        con: Text;
        Qry: Label 'EXEC [dbo].[sp_GetFasaniApps]';
        ID: Integer;
    begin
        ID := 100;
        con := GetconString();
        if con = Undefined then
            exit;
        SqlConnection := SqlConnection.SqlConnection(con);
        SqlConnection.Open();
        SqlCommand := SqlConnection.CreateCommand();
        SqlCommand.CommandText := Qry;
        SqlDataReader := SqlCommand.ExecuteReader();

        while SqlDataReader.read() do begin
            ID := ID + 1;
            RepVerify.Init();
            RepVerify.StoreNo := RetailSetup."Local Store No.";
            RepVerify.Terminal := Location.Code;
            RepVerify.DB_Id := ID;
            RepVerify.Time := Time();
            RepVerify.Date := Today();
            RepVerify.DB_Name := SqlDataReader.Item('Name');
            RepVerify.IpAddress := 'EXTENSIONES';
            RepVerify.DriveLetter := SqlDataReader.Item('Version');
            if not RepVerify.Insert(true) then
                RepVerify.Modify(true);
        end;
    end;
    #endregion
    #region [Local procedures]
    local procedure GetconString(): Text
    var
        connString: Text;
    begin
        if RetailSetup.Get() then
            if Location.GET(RetailSetup."Distribution Location") then;

        if Location.IsEmpty then
            exit(Undefined);

        connString := 'Data Source=' + Location."Db Server Name" + ';Initial Catalog=' + Location."Db. Path && Name" + ';User ID=' + Location."User ID" + ';Password=' + Location."Password" + ';';

        exit(connString);
    end;
    #endregion
}