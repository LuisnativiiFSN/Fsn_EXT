table 50013 "FSN Instruccion"
{
    DataClassification = ToBeClassified;
    Caption = 'Instruction';

    fields
    {
        field(1; ReceiptNo; code[20])
        {
            DataClassification = ToBeClassified;
        }
        field(2; "FSN Comentario 1"; Text[100])
        {
            DataClassification = ToBeClassified;
        }
        field(3; "FSN Comentario 2"; Text[100])
        {
            DataClassification = ToBeClassified;
        }
        field(4; "FSN Comentario 3"; Text[100])
        {
            DataClassification = ToBeClassified;
        }
        field(5; "FSN Mensaje 1"; Text[100])
        {
            DataClassification = ToBeClassified;
        }
        field(6; "FSN Mensaje 2"; Text[100])
        {
            DataClassification = ToBeClassified;
        }
        field(8; TextoValor; Text[100])
        {
            DataClassification = ToBeClassified;
        }
        field(10; StoreNo; Text[100])
        {
            DataClassification = ToBeClassified;
        }
        field(11; EntryTypeDescription; Text[100])
        {
            DataClassification = ToBeClassified;
        }
        field(12; "First Name"; Text[100])
        {
            DataClassification = ToBeClassified;
        }
        field(13; "Primary Phone"; Text[100])
        {
            DataClassification = ToBeClassified;
        }
        field(14; Region; Text[100])
        {
            DataClassification = ToBeClassified;
        }

        field(15; "Document Type Sales"; Option)
        {
            Caption = 'Document Type Sales';
            OptionCaption = ' ,Factura,Credito Fiscal';
            OptionMembers = " ",Factura,"Credito Fiscal";
        }
    }

    keys
    {
        key(Key1; ReceiptNo)
        {
            Clustered = true;
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