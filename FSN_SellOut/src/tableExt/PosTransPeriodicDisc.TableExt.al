tableextension 50046 "FSN Pos Trans Periodic Disc" extends "LSC POS Trans. Per. Disc. Type"
{
    fields
    {
        field(50170; "FSN Sell Out Amount"; Decimal)
        {
            DataClassification = ToBeClassified;
        }
        field(50171; "FSN Sell Out Type"; Enum "FSN Sell Out Value Type")
        {
            DataClassification = ToBeClassified;
            // Caption = 'ENU=Nothing,Vendor/Percent,Bank/Percent', comment = 'ESP="Ninguno,Proveedor/Procentaje,Banco/Porcentaje"';
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