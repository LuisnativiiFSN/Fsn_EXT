table 50103 "PITS Sub Line"
{
    DataClassification = ToBeClassified;

    fields
    {
        field(1; "No."; Code[30])
        {
            Caption = 'No.';
            DataClassification = ToBeClassified;
        }
        field(2; "Line No."; Integer)
        {
            Caption = 'Line No.';
            DataClassification = ToBeClassified;
        }
        field(3; "Sub Line No."; Integer)
        {
            Caption = 'Sub Line No.';
            AutoIncrement = true;
            DataClassification = ToBeClassified;
        }
        field(4; "No. Remision"; Code[35])
        {
            Caption = 'No. Remision';
            DataClassification = ToBeClassified;
        }
        field(5; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            TableRelation = Item;
            DataClassification = ToBeClassified;
        }
        field(6; Lote; Code[20])
        {
            Caption = 'Lote';
            DataClassification = ToBeClassified;
        }
        field(7; Quantity; Decimal)
        {
            Caption = 'Quantity';
            DecimalPlaces = 0 : 5;
            DataClassification = ToBeClassified;
        }
        field(8; "Expiration Date"; Date)
        {
            Caption = 'Expiration Date';
            DataClassification = ToBeClassified;
        }

    }

    keys
    {
        key(PK; "No.", "Line No.", "Sub Line No.")
        {
            Clustered = true;
        }
    }
}