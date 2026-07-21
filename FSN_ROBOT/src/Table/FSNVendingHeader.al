table 50106 "FSN Vending Header"
{
    DataClassification = ToBeClassified;

    fields
    {
        field(1; "idMachine"; Integer)
        {
        }
        field(2; "idTransaction"; Integer)
        {
        }
        field(3; "DateHours"; DateTime)
        {
        }
        field(5; "DTE AuthNumber"; Code[36])
        {
            Caption = 'DTE AuthNumber';
        }
        field(6; "DTE Invoice"; Code[31])
        {
            Caption = 'DTE Invoice';
        }
        field(7; "Signature Validation"; Text[50])
        {
            Caption = 'Signature Validation';
        }
        field(9; "Process"; Boolean)
        {
        }
        field(10; "DUI"; Code[20])
        {
        }
        field(11; "Document Type"; Enum "Sales Document Type")
        {
            Caption = 'Document Type';
        }
        field(12; "Payment"; decimal)
        {
            Caption = 'Payment';
        }
        field(13; "FC No"; Code[20])
        {
            Caption = 'FC No';
        }
        field(14; "FC Message Error"; text[250])
        {
            Caption = 'FC Message Error';
        }

    }

    keys
    {
        key(PK; "idMachine", "idTransaction")
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
        // Add changes to field groups here
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