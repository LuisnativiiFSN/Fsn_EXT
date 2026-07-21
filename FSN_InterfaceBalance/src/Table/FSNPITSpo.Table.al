table 50044 "FSN PITS_po"
{

    fields
    {
        field(10; Suc_id; Code[10])
        {
        }
        field(20; suc_nombre; Text[30])
        {
        }
        field(30; Boleta_id; Code[20])
        {
        }
        field(40; NUM_COMPROBANTE; Code[20])
        {
        }
        field(50; FECHA; Date)
        {
        }
        field(55; FECHA_REGISTRO; Date)
        {
        }
        field(60; fDIA; Integer)
        {
        }
        field(70; fMES; Integer)
        {
        }
        field(80; fANN; Integer)
        {
        }
        field(90; prov_id; Code[20])
        {
        }
        field(100; prov_nombre; Text[50])
        {
        }
        field(110; factura_subtotal; Decimal)
        {
        }
        field(120; factura_descuento; Decimal)
        {
        }
        field(130; factura_imp_venta; Decimal)
        {
        }
        field(140; SALDO_COMPR; Decimal)
        {
        }
        field(150; TieneNota; Text[10])
        {
        }
        field(160; NCVal; Decimal)
        {
        }
        field(170; NCnum; Code[20])
        {
        }
        field(180; Procesado; Boolean)
        {
        }
        field(181; Fecha_Documento; Date)
        {
        }
        field(182; "DTE CONTROL"; Text[50])
        {
        }
        field(183; "Replication Counter"; Integer)
        {

            trigger OnValidate()
            var
                FSNPITSpo: Record "FSN PITS_po";
            begin
                FSNPITSpo.RESET;
                FSNPITSpo.SETCURRENTKEY("Replication Counter");
                IF FSNPITSpo.FINDLAST THEN
                    "Replication Counter" := FSNPITSpo."Replication Counter" + 1
                ELSE
                    "Replication Counter" := 1;
            end;
        }

    }

    keys
    {
        key(Key1; NUM_COMPROBANTE, prov_id)
        {
            Clustered = true;
        }
        key(Key2; "Replication Counter")
        {
        }

    }

    fieldgroups
    {
    }
    trigger OnInsert()
    begin
        VALIDATE("Replication Counter");
    end;

    trigger OnModify()
    begin
        VALIDATE("Replication Counter");
    end;

    trigger OnRename()
    begin
        VALIDATE("Replication Counter");
    end;
}

