tableextension 50150 "FSN Transfer Header" extends "Transfer Header"
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