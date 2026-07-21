table 50038 "FSN AP - Pro Purch. Invoices"
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

