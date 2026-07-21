tableextension 50045 "FSN Periodic Discount Line" extends "LSC Periodic Discount Line"
{
    fields
    {
        field(50170; "FSN Barcode No."; Code[20])
        {
            DataClassification = ToBeClassified;
        }
        field(50171; "FSN Sell Out Type"; Enum "FSN Sell Out Value Type")
        {
            DataClassification = ToBeClassified;
            trigger OnValidate()
            begin
                IF "FSN Sell Out Type" = "FSN Sell Out Type"::Nothing THEN
                    "FSN Value Sell Out" := 0;
            end;
        }
        field(50172; "FSN Value Sell Out"; Decimal)
        {
            MinValue = 0;
            MaxValue = 100;
            DataClassification = ToBeClassified;
        }
    }

    var
        myInt: Integer;

    trigger OnInsert()
    var
        myInt: Integer;
    begin
        "FSN Sell Out Type" := "FSN Sell Out Type"::Nothing;
    end;
}