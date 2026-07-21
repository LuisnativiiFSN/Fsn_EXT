tableextension 50151 "FSN Transf. Ship. Header" extends "Transfer Shipment Header"
{
    fields
    {
        field(60001; "FSN Internal Control"; Code[50])
        {
            Caption = 'FSN Internal Control';
        }
    }
    var
        myInt: Integer;
}