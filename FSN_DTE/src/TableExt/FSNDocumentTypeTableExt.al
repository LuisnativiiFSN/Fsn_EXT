tableextension 50149 "Document Tpe TableExt" extends "Document Sub Type"
{
    fields
    {
        field(10000; "DTE Serie No"; Code[20])
        {
            Caption = 'DTE Serie No';
            TableRelation = "No. Series";
        }

        field(20000; "DTE Certify"; Boolean)
        {
            Caption = 'DTE Certify';
        }
    }

    keys
    {
        // Add changes to keys here
    }

    fieldgroups
    {
        // Add changes to field groups here
    }

    var
        myInt: Integer;
}