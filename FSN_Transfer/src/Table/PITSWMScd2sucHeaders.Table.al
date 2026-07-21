table 50083 PITS_WMScd2sucHeaders
{
    //WVILLALTA 10.21             - C/AL to AL
    fields
    {
        field(2; No_; Code[30])
        {
        }
        field(3; "Source No_"; Code[20])
        {
        }
        field(4; Rapidito; Boolean)
        {
        }
        field(5; "Starting Date"; Date)
        {
        }
        field(6; "Ending Date"; Date)
        {
        }
        field(7; Lineas; Integer)
        {
        }
        field(8; Nivel; Integer)
        {
        }
        field(9; Transfer; Boolean)
        {
        }
        field(10; Completado; Boolean)
        {
        }
        field(20; "Ultimo Error"; Text[150])
        {
        }
        field(30; "Hora Creado"; DateTime)
        {
        }
        field(31; "Replication Counter"; Integer)
        {

            trigger OnValidate()
            var
                PITSWMScd2sucHeaders: Record PITS_WMScd2sucHeaders;
            begin
                PITSWMScd2sucHeaders.RESET;
                PITSWMScd2sucHeaders.SETCURRENTKEY("Replication Counter");
                IF PITSWMScd2sucHeaders.FINDLAST THEN
                    "Replication Counter" := PITSWMScd2sucHeaders."Replication Counter" + 1
                ELSE
                    "Replication Counter" := 1;
            end;
        }
    }

    keys
    {
        key(Key1; No_, "Source No_", Nivel)
        {
            Clustered = true;
        }
        key(Key2; "Replication Counter")
        {
        }
    }

    fieldgroups
    {
    }
    trigger OnInsert()
    begin
        VALIDATE("Replication Counter");
    end;

    trigger OnModify()
    begin
        VALIDATE("Replication Counter");
    end;

    trigger OnRename()
    begin
        VALIDATE("Replication Counter");
    end;
}

