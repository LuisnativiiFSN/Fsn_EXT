table 50024 "FSN KardexRep"
{

    fields
    {
        field(1; Clave; Code[30])
        {
        }
        field(2; "Unit of Measure Code"; Code[10])
        {
            Description = 'From Barcodes table';
        }
        field(3; "Barcode No."; Code[20])
        {
            Description = 'From Barcodes table';
        }
        field(4; Description; Text[50])
        {
            Description = 'From Barcodes table';
        }
        field(5; "Sales Amount (Actual)"; Decimal)
        {
            Description = 'From Item Ledger Entry (Calc)';
        }
        field(6; "Item No."; Code[20])
        {
            Description = 'From Item Ledger Entry';
        }
        field(7; "Entry No."; Integer)
        {
            Description = 'From Item Ledger Entry';
        }
        field(8; "External Document No."; Code[35])
        {
            Description = 'From Item Ledger Entry';
        }
        field(9; "Posting Date"; Date)
        {
            Description = 'From Item Ledger Entry';
        }
        field(10; "Entry Type"; Option)
        {
            Caption = 'Entry Type';
            Description = 'From Item Ledger Entry';
            OptionCaption = 'Purchase,Sale,Positive Adjmt.,Negative Adjmt.,Transfer,Consumption,Output, ,Assembly Consumption,Assembly Output';
            OptionMembers = Purchase,Sale,"Positive Adjmt.","Negative Adjmt.",Transfer,Consumption,Output," ","Assembly Consumption","Assembly Output";
        }
        field(11; "Document No."; Code[35])
        {
            Description = 'From Item Ledger Entry';
        }
        field(12; Quantity; Decimal)
        {
            Description = 'From Item Ledger Entry';
        }
        field(13; "Cost Amount (Actual)"; Decimal)
        {
            Description = 'From Item Ledger Entry';
        }
        field(14; "Purchase Amount (Actual)"; Decimal)
        {
            Description = 'From Item Ledger Entry';
        }
        field(15; "Location Code"; Code[10])
        {
            Description = 'From Item Ledger Entry';
        }
        field(16; "Country/Region Code"; Code[10])
        {
            Description = 'From Item Ledger Entry';
        }
        field(17; "Cost Amount (Expected)"; Decimal)
        {
            Description = 'From Item Ledger Entry';
        }
        field(18; Name; Text[100])
        {
            Description = 'From Vendor Table';
        }
        field(19; "Document Type"; Option)
        {
            Caption = 'Document Type';
            Description = 'From Item Ledger Entry';
            OptionCaption = ' ,Sales Shipment,Sales Invoice,Sales Return Receipt,Sales Credit Memo,Purchase Receipt,Purchase Invoice,Purchase Return Shipment,Purchase Credit Memo,Transfer Shipment,Transfer Receipt,Service Shipment,Service Invoice,Service Credit Memo,Posted Assembly';
            OptionMembers = " ","Sales Shipment","Sales Invoice","Sales Return Receipt","Sales Credit Memo","Purchase Receipt","Purchase Invoice","Purchase Return Shipment","Purchase Credit Memo","Transfer Shipment","Transfer Receipt","Service Shipment","Service Invoice","Service Credit Memo","Posted Assembly";
        }
        field(20; ItemUnitCost; Decimal)
        {
            Description = 'From Items';
        }
        field(21; Correlativo; Integer)
        {
            Description = 'Para prereporte';
        }
        field(22; Costo; Decimal)
        {
            Description = 'Para prereporte';
        }
        field(23; QtyEnt; Decimal)
        {
            Description = 'Para prereporte';
        }
        field(24; QtySal; Decimal)
        {
            Description = 'Para prereporte';
        }
        field(25; AmtEnt; Decimal)
        {
            Description = 'Para prereporte';
        }
        field(26; AmtSal; Decimal)
        {
            Description = 'Para prereporte';
        }
        field(27; QtyBal; Decimal)
        {
            Description = 'Para prereporte';
        }
        field(28; AmtBal; Decimal)
        {
            Description = 'Para prereporte';
        }
        field(29; Tipo; Text[50])
        {
            Description = 'Para prereporte';
        }
        field(30; Transaccion; Integer)
        {
            Description = 'Para prereporte';
        }
        field(31; Fecha; Date)
        {
            Description = 'Para prereporte';
        }
        field(32; Documento; Text[35])
        {
            Description = 'Para prereporte';
        }
        field(33; Proveedor; Text[100])
        {
            Description = 'Para prereporte';
        }
        field(34; Nacional; Code[10])
        {
            Description = 'Para Prereporte';
        }
        field(35; SalesPrice; Decimal)
        {
        }
        field(36; "Lote No."; Code[20])
        {
        }
        field(37; "Fecha Vencimiento"; Date)
        {
        }
    }

    keys
    {
        key(Key1; Clave, "Entry No.", "Entry Type", "Document No.", "External Document No.")
        {
            Clustered = true;
            MaintainSIFTIndex = true;
        }
        key(Key2; Clave, "Posting Date", "Entry Type", "External Document No.")
        {
            MaintainSIFTIndex = true;
        }
    }

    fieldgroups
    {
    }
}

