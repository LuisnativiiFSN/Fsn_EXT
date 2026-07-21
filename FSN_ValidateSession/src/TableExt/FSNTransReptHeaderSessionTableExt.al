tableextension 50117 "FSN Transfer Receipt Header" extends "Transfer Receipt Header"
{
    fields
    {
        field(50500; "FSN User"; Code[20])
        {
            DataClassification = ToBeClassified;              
        }
    }

    var
        myInt: Integer;
}