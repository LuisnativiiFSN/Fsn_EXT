page 50065 "FSN Replication Verify"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "FSN Replication Verify";
    Caption = 'FSN Replication Verify';
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(database)
            {
                Visible = DefaultView;
                field(StoreNo; Rec.StoreNo)
                {

                    Caption = 'Store No.';
                }
                field(Terminal; Rec.Terminal)
                {
                    Caption = 'Terminal';
                }
                field(Date; Rec.Date)
                {
                    Caption = 'Date';
                }
                field(Time; Rec.Time)
                {
                    Caption = 'Time';
                }
                field(IpAddress; Rec.IpAddress)
                {
                    Caption = 'IpAddress';
                }
                field(DriveLetter; Rec.DriveLetter)
                {
                    Caption = 'DriveLetter';
                }
                field(DriveSpace; Rec.DriveSpace)
                {
                    Caption = 'DriveSpace';
                }
                field(DB_Id; Rec.DB_Id)
                {
                    Caption = 'DB_Id';
                }
                field(DB_Name; Rec.DB_Name)
                {
                    Caption = 'DB_Name';
                }
                field(TotalSizeMB; Rec.TotalSizeMB)
                {
                    Caption = 'TotalSizeMB';
                }
                field(TotalSizeGB; Rec.TotalSizeGB)
                {
                    Caption = 'TotalSizeGB';
                }
                field(FreeSpaceMB; Rec.FreeSpaceMB)
                {
                    Caption = 'FreeSpaceMB';
                }
                field(FreeSpaceGB; Rec.FreeSpaceGB)
                {
                    Caption = 'FreeSpaceGB';
                }
                field(FreeSpacePercentage; Rec.FreeSpacePercentage)
                {
                    Caption = 'FreeSpacePercentage';
                }
                field(UsedSpacePercentage; Rec.UsedSpacePercentage)
                {
                    Caption = 'UsedSpacePercentage';
                }
                field(SizeDB_Log_MB; Rec.SizeDB_Log_MB)
                {
                    Caption = 'SizeDB_Log_MB';
                }
                field(SizeDB_LogGB; Rec.SizeDB_LogGB)
                {
                    Caption = 'SizeDB_LogGB';
                }
                field(SizeDB_DataMB; Rec.SizeDB_DataMB)
                {
                    Caption = 'SizeDB_DataMB';
                }
                field(SizeDB_DataGB; Rec.SizeDB_DataGB)
                {
                    Caption = 'SizeDB_DataGB';
                }
            }
            repeater(Apps)
            {
                Visible = not DefaultView;
                field(Store; Rec.StoreNo)
                {
                    Caption = 'Store';
                }
                field(DateApps; Rec.Date)
                {
                    Caption = 'Date';
                }
                field(TimeApps; Rec.Time)
                {
                    Caption = 'Time';
                }
                field(Name; Rec.DB_Name)
                {
                    Caption = 'Name';
                }
                field(Version; Rec.DriveLetter)
                {
                    Caption = 'Version';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Insertar)
            {
                ApplicationArea = All;

                trigger OnAction()
                begin
                    Replication.ReplicationVerify();
                end;
            }
            action(insertApps)
            {
                ApplicationArea = All;
                Caption = 'Insert Apps';
                Image = Insert;
                trigger OnAction()
                begin
                    Replication.AppsList();
                end;
            }
            action(showApps)
            {
                ApplicationArea = All;
                Caption = 'Show Apps';
                Image = FilterLines;
                trigger OnAction()
                begin
                    DefaultView := false;
                    ShowContent();
                end;
            }
            action(showDatabase)
            {
                ApplicationArea = All;
                Caption = 'Show Database';
                Image = FilterLines;
                trigger OnAction()
                begin
                    DefaultView := true;
                    ShowContent();
                end;
            }
        }
    }

    trigger OnOpenPage()
    var
    begin
        DefaultView := true;
        ShowContent();
    end;

    var
        Replication: Codeunit "FSN Replication server";
        DefaultView: boolean;
        string: label 'EXTENSIONES';

    local procedure ShowContent()
    begin
        if DefaultView then
            Rec.SetFilter(IpAddress, '<> %1', string)
        else
            Rec.SetFilter(IpAddress, '= %1', string);
    end;
}