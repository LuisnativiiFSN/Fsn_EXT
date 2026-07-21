tableextension 50125 "FSN Purchase Price" extends "Purchase Price"
{
    fields
    {
        field(60000; "FSN Cost After NC"; Decimal)
        {
            Caption = 'Costo despues de NC';
            DataClassification = ToBeClassified;
        }
    }

    var
        myInt: Integer;
}