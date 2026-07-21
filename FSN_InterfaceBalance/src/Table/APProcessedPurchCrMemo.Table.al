/* Se confirma con WVILLALTA reutilizar este ID objeto para Purchase: FSN Recep. Purch. DTE
table 50039 "FSN AP - Pro Purch. Cr. Memo"
{

    fields
    {
        field(10; "No."; Code[20])
        {
            Description = 'Numero de factura de compra';
        }
    }

    keys
    {
        key(Key1; "No.")
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
    }
}
*/