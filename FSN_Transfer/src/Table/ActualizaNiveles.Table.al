table 50065 ActualizacionNiveles
{
    DataClassification = ToBeClassified;

    fields
    {
        field(1; ItemNo; Code[20])
        {
            DataClassification = ToBeClassified;

        }
        field(2; CodeBar; Code[20])
        {
            DataClassification = ToBeClassified;

        }
        field(3; NoNivelCD; Code[10])
        {
            DataClassification = ToBeClassified;

        }
        field(4; Fecha; Date)
        {
            DataClassification = ToBeClassified;

        }
        field(5; TIme; Time)
        {
            DataClassification = ToBeClassified;

        }
        field(6; "Unit of Measure"; Code[10])
        {
            DataClassification = ToBeClassified;

        }
        field(7; InventoryCD; Decimal)
        {
            DataClassification = ToBeClassified;

        }
        field(8; CodEBS; Code[50])
        {
            DataClassification = ToBeClassified;

        }
    }

    keys
    {
        key(Key1; ItemNo)
        {
            MaintainSiftIndex = true;
            Clustered = true;
        }
        key(Key2; CodeBar)
        {

        }
    }

    var
        myInt: Integer;

    trigger OnInsert()
    begin

    end;

    trigger OnModify()
    begin

    end;

    trigger OnDelete()
    begin

    end;

    trigger OnRename()
    begin

    end;

}