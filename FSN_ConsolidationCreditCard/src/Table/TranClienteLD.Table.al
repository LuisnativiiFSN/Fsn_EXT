table 50032 "FSN TranClienteLD"
{

    fields
    {
        field(1; "Transaction Date"; Date)
        {
            Description = 'Fecha de transaccion';
        }
        field(2; "Document Type"; Option)
        {
            Description = '(1-Factura, 2-Pago, 3-Nota Credito)';
            OptionMembers = Invoice,Payment,CreditNote;
        }
        field(3; "Document No."; Code[20])
        {
            Description = 'Numero documento';
        }
        field(4; "Customer No."; Code[20])
        {
            Description = 'Codigo de Cliente';
        }
        field(5; Amount; Decimal)
        {
            Description = 'Valor';
        }
        field(6; Posted; Boolean)
        {
            Description = 'Posteado?';
        }
        field(7; "Date Posted"; Date)
        {
            Description = 'Fecha posteado';
        }
        field(8; "Time Posted"; Time)
        {
            Description = 'Hora posteado';
        }
        field(9; Status; Code[20])
        {
            Description = 'DUPL=Duplicidad,FALTA=No se encontro referencia EBS, POST=Procesado exitosamente';
        }

        field(10; "Retrieved from Receipt No"; Code[20])
        {
            Description = 'N° Recibo Recuperado';
        }

        field(11; "Refund Receipt No"; Code[20])
        {
            Description = 'N° Recibo de reembolso';
        }
    }

    keys
    {
        key(Key1; "Customer No.", "Document Type", "Document No.")
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
    }
}

