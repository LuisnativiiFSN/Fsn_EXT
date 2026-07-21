table 50023 "FSN InterfazCreditos"
{

    fields
    {
        field(1; "Customer No."; Code[20])
        {
            Description = 'Customer Id';
        }
        field(2; ReferenciaEBS; Code[20])
        {
            Description = 'Referencia EBS';
        }
        field(3; "Credit Limit"; Decimal)
        {
            Description = 'Credit Limit Amount';
        }
        field(4; Balance; Decimal)
        {
            Description = 'Current Balnce for Customer';
        }
        field(5; EBS; Boolean)
        {
            Description = 'Saldo de EBS';
        }
        field(6; LDCOM; Boolean)
        {
            Description = 'Saldo proporcionado por LDCOM';
        }
        field(7; LSR; Boolean)
        {
            Description = 'Saldo proporcionado por LSREtail';
        }
    }

    keys
    {
        key(Key1; "Customer No.")
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
    }
}

