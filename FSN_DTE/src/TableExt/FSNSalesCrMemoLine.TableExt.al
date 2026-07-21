tableextension 50145 "FSN Sales Cr.Memo Line" extends "Sales Cr.Memo Line"
{
    fields
    {
        field(80010; "FSN Base Affect"; Decimal)
        {
            Caption = 'FSN Base Affect';

        }
    }

    var
        myInt: Integer;
}