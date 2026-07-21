tableextension 50152 "FSN Transfer Receipt Header" extends "Transfer Receipt Header"
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