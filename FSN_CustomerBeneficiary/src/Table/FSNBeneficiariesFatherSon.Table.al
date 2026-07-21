table 50058 "FSN Benef. Father Son"
{

    fields
    {
        field(1; "Customer No."; Code[20])
        {
            Description = 'Customer Code';
            TableRelation = Customer."No.";
        }
        field(2; "Card No."; Code[20])
        {
            Description = 'Assistant/Dependant Code';
        }
        field(3; Name; Text[50])
        {
            Description = 'Assistant/Dependant Name';

            trigger OnValidate()
            begin
                Rec.Name := UPPERCASE(Rec.Name);
            end;
        }
        field(4; Relation; Enum "FSN Benef. Father/Son Enum")
        {
            Description = 'Depedent relation to Assitant';
        }
        field(5; Poliza; Code[20])
        {
            Description = 'Insurance Number';
        }
        field(6; Titular; Code[20])
        {
            Description = 'Codigo de Titular';
        }

        field(7; NIT; Code[20])
        {
            Description = 'NIT';
        }

        field(8; DUI; Code[10])
        {
            Description = 'DUI';
        }
        field(9; mail; text[102])
        {
            Description = 'mail';
        }
    }

    keys
    {
        key(Key1; "Customer No.", "Card No.")
        {
            Clustered = true;
        }
        key(Key2; "Customer No.", Titular)
        {
        }
    }

    fieldgroups
    {
    }

    trigger OnDelete()
    begin
        CreateAction(2);
    end;

    trigger OnInsert()
    begin
        CreateAction(0);
    end;

    trigger OnModify()
    begin
        CreateAction(1);
    end;

    trigger OnRename()
    begin
        CreateAction(3);
    end;

    procedure CreateAction(Type: Integer)
    var
        RecRef: RecordRef;
        xRecRef: RecordRef;
        ActionsMgt: Codeunit "LSC Actions Management";
    begin

        RecRef.GETTABLE(Rec);
        xRecRef.GETTABLE(xRec);
        ActionsMgt.SetCalledByTableTrigger(TRUE);
        ActionsMgt.CreateActionsByRecRef(RecRef, xRecRef, Type);
        RecRef.CLOSE;
        xRecRef.CLOSE;
    end;
}

