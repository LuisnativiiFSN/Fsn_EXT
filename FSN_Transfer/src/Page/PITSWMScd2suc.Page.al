page 50016 "FSN PITSWMScd2suc"
{
    Caption = 'CD Transferencias';
    /*DelayedInsert = false;
    DeleteAllowed = false;
    InsertAllowed = false;
    ModifyAllowed = false;*/
    PageType = List;
    SourceTable = PITS_WMScd2suc;
    ApplicationArea = all;
    UsageCategory = Administration;
    //Permissions 
    //UsageCategory = Lists;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("No."; "No.")
                {
                }
                field("Line No."; "Line No.")
                {
                    // Visible = false;
                }
                field("Starting Date"; "Starting Date")
                {
                }
                field("Ending Date"; "Ending Date")
                {
                    Caption = 'Fecha Vencimiento';
                }
                field("Transfer-from Code"; "Transfer-from Code")
                {
                }
                field("Transfer-to Code"; "Transfer-to Code")
                {
                }
                field(Rapidito; Rapidito)
                {
                }
                field("Consolidated From No."; "Consolidated From No.")
                {
                }
                field("Source No."; "Source No.")
                {
                }
                field("No. Remision"; "No. Remision")
                {
                }
                field("No. Pedido"; "No. Pedido")
                {
                    Caption = 'No. Lote';
                }
                field("Item No."; "Item No.")
                {
                }
                field("Barcode No."; "Barcode No.")
                {
                }
                field(Description; Description)
                {
                }
                field(Costo_EBS; Costo_EBS)
                {
                }
                field(Costo_NAV; Costo_NAV)
                {
                }
                field(Quantity; Quantity)
                {
                }
                field("Qty. to Ship"; "Qty. to Ship")
                {
                }
                field("Unit of Measure"; "Unit of Measure")
                {
                }
                field("Shelf No."; "Shelf No.")
                {
                }
                field(Puesto; Puesto)
                {
                }
                field(TransferComplete; TransferComplete)
                {
                }
                field(Shipped; Shipped)
                {
                }
                field(Completado; Completado)
                {
                }
                field(Order; Order)
                {
                }
                field("Ajuste Pasado"; "Ajuste Pasado")
                {
                }
                field("Shipment Posteado"; "Shipment Posteado")
                {
                }
                field("Date Updated"; "Date Updated")
                {
                    Caption = 'Fecha Modificado';
                }
            }
        }
    }

    actions
    {
    }
}

