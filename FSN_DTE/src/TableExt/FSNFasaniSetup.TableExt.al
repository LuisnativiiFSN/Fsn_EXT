tableextension 50075 "FSN Fasani Setup Ext" extends "FSN Fasani Setup"
{
    fields
    {
        field(10000; "DTE Store"; Code[5])
        {
            Caption = 'DTE Store';
        }
        field(20000; "DTE Terminal"; Code[5])
        {
            Caption = 'DTE Terminal';
        }
    }

    var
        myInt: Integer;
}