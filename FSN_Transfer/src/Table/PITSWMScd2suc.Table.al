table 50018 PITS_WMScd2suc
{
    //WVILLALTA 10.21             - C/AL to AL
    fields
    {
        field(10; "No."; Code[30])
        {
            Caption = 'No.';
            Description = 'Correlativo';
            Editable = false;
        }
        field(20; "Line No."; Integer)
        {
            Caption = 'Line No.';
            Description = 'Numero de linea de detalle de transferencia';
            Editable = false;
        }
        field(30; "Starting Date"; Date)
        {
            Caption = 'Starting Date';
            Description = 'Fecha y hora en que se genero orden de transferencia';
        }
        field(35; "Ending Date"; Date)
        {
            Description = 'Fecha y hora en que se confirmo el pedido desde EBS';
        }
        field(40; "Transfer-from Code"; Code[10])
        {
            Caption = 'Location Code';
            Description = 'Codigo de almacen de donde se enviara la transferencia';
            Editable = false;
            TableRelation = Location;
        }
        field(45; "Transfer-to Code"; Code[10])
        {
            Description = 'Codigo de almacen que recibira la transferencia';
        }
        field(50; "Source No."; Code[20])
        {
            Caption = 'Source No.';
            Description = 'Numero de orden de transferencia';
            Editable = false;
        }
        field(55; "No. Remision"; Code[35])
        {
            Description = 'Numero de nota de remision generada en EBS';
        }
        field(57; "No. Pedido"; Code[20])
        {
            Description = 'Numero de pedido generado en EBS';
        }
        field(60; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            Description = 'Codigo de articulo interno de NAV';
            Editable = false;
            TableRelation = Item;
        }
        field(65; "Barcode No."; Code[20])
        {
        }
        field(67; Description; Text[100])
        {
            Description = 'Nombre del articulo interno de NAV';
        }
        field(68; Costo_EBS; Decimal)
        {
            Description = 'Costo del articulo en EBS';
        }
        field(69; Costo_NAV; Decimal)
        {
            Description = 'Costo del articulo en NAV';
        }
        field(70; Quantity; Decimal)
        {
            Caption = 'Quantity';
            DecimalPlaces = 0 : 5;
            Description = 'Cantidad solicitada a CDF';
            Editable = false;
        }
        field(80; "Qty. to Ship"; Decimal)
        {
            Caption = 'Qty. to Ship';
            DecimalPlaces = 0 : 5;
            Description = 'Cantidad confirmada enviada desde CDF a Sucursal';
            MinValue = 0;
        }
        field(85; "Unit of Measure"; Text[10])
        {
            Description = 'Unidad de Medida de compra interna de NAV';
        }
        field(90; "Shelf No."; Code[10])
        {
            Caption = 'Shelf No.';
            Description = 'Numero de nivel donde se encuentra el producto en CDF';
        }
        field(95; Puesto; Code[10])
        {
            Description = 'Numero de puesto del producto en sala';
        }
        field(100; TransferComplete; Boolean)
        {
            Description = 'Bandera indica la orden de transferencia fue importada hacia EBS';
        }
        field(110; Shipped; Boolean)
        {
            Description = 'Bandera indica la orden de transferencia fue enviada desde CDF a Salas';
        }
        field(120; "Consolidated From No."; Code[20])
        {
            Description = 'Codigo de pedidos consolidado generado automaticamente en NAV';
        }
        field(130; Rapidito; Boolean)
        {
            Description = 'Bandera indica si un pedido es consolidado (0) o rapidito (1)';
        }
        field(140; Completado; Boolean)
        {
            Description = 'Bandera indica si la orden de transferencia ya fue procesada';
        }
        field(141; "Order"; Integer)
        {
            Description = 'numero que indica el orden de impresion de nota de remision';
        }
        field(50000; "Ajuste Pasado"; Boolean)
        {
            Description = 'Bandera para indicar que la linea paso del ajuste positivo';
        }
        field(50001; "Shipment Posteado"; Boolean)
        {
        }
        field(50002; "Date Updated"; DateTime)
        {
            Caption = 'Date Updated';
        }

        field(50003; "Replication Counter"; Integer)
        {

            trigger OnValidate()
            var
                PITSWMScd2suc: Record PITS_WMScd2suc;
            begin
                PITSWMScd2suc.RESET;
                PITSWMScd2suc.SETCURRENTKEY("Replication Counter");
                IF PITSWMScd2suc.FINDLAST THEN
                    "Replication Counter" := PITSWMScd2suc."Replication Counter" + 1
                ELSE
                    "Replication Counter" := 1;
            end;
        }

        field(50004; "FSN Warehouse Receipt No."; Code[20])
        {
            Editable = false;
        }

        field(50005; "FSN TransferHistorico"; Option)
        {
            Caption = 'FSN Transfer Historico';
            Description = 'Control de flujo del proceso de transferencia';
            Editable = false;
            OptionMembers = Abierto,Lanzado,Registrado,Historico,"WR Eliminado";
            OptionCaption = 'Abierto,Lanzado,Registrado,Histórico,WR Eliminado';
            InitValue = Abierto;
        }

        field(50006; "Lot No."; Code[50])
        {
            Caption = 'Lot No.';
            Description = 'N�mero de lote para productos con seguimiento - OBSOLETO: Usar No. Pedido';
            ObsoleteState = Pending;
            ObsoleteReason = 'Replaced by automatic tracking using No. Pedido field';
        }

        field(50007; "Expiration Date"; Date)
        {
            Caption = 'Expiration Date';
            Description = 'Fecha de caducidad/vencimiento del lote - OBSOLETO: Usar Date Updated';
            ObsoleteState = Pending;
            ObsoleteReason = 'Replaced by automatic tracking using Date Updated field';
        }
        field(50008; "FSN Quantity Scan"; Decimal)
        {
            Caption = 'Cantidad Escaneada';
            Description = 'Cantidad escaneada para el producto';
            DecimalPlaces = 0 : 5;
        }
    }

    keys
    {
        key(Key1; "No.", "Line No.")
        {
            Clustered = true;
        }
        key(Key2; "No.", TransferComplete, Shipped, Completado)
        {
        }
        key(Key3; "Source No.", "Item No.")
        {
        }
        key(Key4; "Source No.", "Shelf No.")
        {
            MaintainSIFTIndex = true;
            SumIndexFields = Quantity, "Qty. to Ship";
        }
        key(Key5; "Replication Counter")
        {
        }
        key(Key6; "No. Remision", Completado, "FSN TransferHistorico")
        {
        }
        key(Key7; "FSN Warehouse Receipt No.", "FSN TransferHistorico")
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

