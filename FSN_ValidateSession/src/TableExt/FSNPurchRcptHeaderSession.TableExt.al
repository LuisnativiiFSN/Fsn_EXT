tableextension 50115 "FSN Purch. Rcpt. Header" extends "Purch. Rcpt. Header"
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