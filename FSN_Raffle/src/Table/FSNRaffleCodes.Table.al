table 50077 "FSN Raffle Codes"
{

    fields
    {
        field(10; "POS Terminal No"; Code[10])
        {
        }
        field(20; NoRifa; Code[30])
        {
            TableRelation = "FSN Rifas".NoRifa;
        }
        field(30; Codigo; Code[20])
        {
        }
        field(40; Used; Boolean)
        {
            Editable = false;
        }
        field(50; "Receipt No"; Code[20])
        {
            Editable = false;
        }
        field(60; Date; Date)
        {
            Editable = false;
        }
        field(70; Hours; Time)
        {
            Editable = false;
        }
    }

    keys
    {
        key(Key1; "POS Terminal No", NoRifa, Codigo)
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
    }
}

