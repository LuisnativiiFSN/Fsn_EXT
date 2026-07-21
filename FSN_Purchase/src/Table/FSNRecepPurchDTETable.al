table 50039 "FSN Recep. Purch. DTE"
{
    //JHERNANDEZ 09-2024
    Caption = 'FSN Recepcion Compra DTE';

    fields
    {
        field(10; "No."; Code[20])
        {
            Caption = 'No.';
            //AutoIncrement = true;
            Editable = false;
        }
        field(20; "VAT Registration No."; Text[20])
        {
            Caption = 'VAT Registration No.';
        }
        field(30; "DTE AuthNumber"; Code[36])
        {
            Caption = 'DTE AuthNumber';
        }
        field(40; "DTE Invoice"; Code[31])
        {
            Caption = 'DTE Invoice';
        }
        field(50; "Signature Validation"; Text[50])
        {
            Caption = 'Signature Validation';
        }
        field(60; "Issue Date"; DateTime)
        {
            Caption = 'Issue Date';
        }
        field(70; "Entry Date"; DateTime)
        {
            Caption = 'Entry Date';
        }
        field(80; "Record Processed"; Boolean)
        {
            Caption = 'Record Processed';
        }
        field(90; Subtotal; Decimal)
        {
            Caption = 'Subtotal';
        }
        field(100; IVA; Decimal)
        {
            Caption = 'IVA';
        }
        field(110; Total; Decimal)
        {
            Caption = 'Total';
        }


    }
    keys
    {
        key(Key1; "No.")
        {
            Clustered = true;
        }

    }
}