page 50120 "FSN Warehouse Receipts"
{
    ApplicationArea = Warehouse;
    Caption = 'FSN Recepcion Almacen';
    CardPageID = "FSN PITS Whse Receipt Card";
    DataCaptionFields = "No.";
    Editable = false;
    PageType = List;
    SourceTable = "Warehouse Receipt Header";
    UsageCategory = Lists;

    layout
    {
        area(content)
        {
            repeater(Control1)
            {
                ShowCaption = false;
                field("No."; "No.")
                {
                    ApplicationArea = Warehouse;
                    ToolTip = 'Número de Recepción';
                }
                field("Location Code"; "Location Code")
                {
                    ApplicationArea = Location;
                    ToolTip = 'Código de almacén donde se reciben los artículos';
                }
                field("Vendor Shipment No."; "Vendor Shipment No.")
                {
                    ApplicationArea = Warehouse;
                    ToolTip = 'Número de remisión del proveedor o documento externo PITS';
                }
                field("FSN External Document No."; "FSN External Document No.")
                {
                    ApplicationArea = Warehouse;
                    ToolTip = 'Número de Transferencia (TR) del documento externo';
                }
                field("Assignment Date"; "Assignment Date")
                {
                    ApplicationArea = Warehouse;
                    ToolTip = 'Fecha de asignación de la recepción';
                }
                field(Status; Status)
                {
                    ApplicationArea = Warehouse;
                    Caption = 'Status';
                    ToolTip = 'Estado del proceso de recepción automática';
                }
                field("FSN Proc Status"; "FSN Proc Status")
                {
                    ApplicationArea = Warehouse;
                    Caption = 'Estado Proceso';
                    ToolTip = 'Estado del procesamiento del WR (por procesar, procesando o error).';
                }
                field("FSN Proc Error"; "FSN Proc Error")
                {
                    ApplicationArea = Warehouse;
                    Caption = 'Error Proceso';
                    ToolTip = 'Ultimo error reportado al procesar el WR.';
                }
                field("FSN Estado Transferencia Option"; EstadoOption)
                {
                    ApplicationArea = Warehouse;
                    Caption = 'Estado Transferencia';
                    ToolTip = 'Estado actual del proceso de transferencia (filtrable)';
                    OptionCaption = 'Abierto,Lanzado,Registrado,Histórico,WR Eliminado';
                    StyleExpr = EstadoStyle;
                }
            }
        }
        area(factboxes)
        {
            systempart(Control1900383207; Links)
            {
                ApplicationArea = RecordLinks;
                Visible = false;
            }
            systempart(Control1905767507; Notes)
            {
                ApplicationArea = Notes;
                Visible = true;
            }
        }
    }

    actions
    {
        area(navigation)
        {
            group("&Receipt")
            {
                Caption = '&Receipt';
                Image = Receipt;
                action("Co&mments")
                {
                    ApplicationArea = Warehouse;
                    Caption = 'Co&mments';
                    Image = ViewComments;
                    RunObject = Page "Warehouse Comment Sheet";
                    RunPageLink = "Table Name" = CONST("Whse. Receipt"),
                                  Type = CONST(" "),
                                  "No." = FIELD("No.");
                    ToolTip = 'View or add comments for the record.';
                }
                action("Posted &Whse. Receipts")
                {
                    ApplicationArea = Warehouse;
                    Caption = 'Posted &Whse. Receipts';
                    Image = PostedReceipts;
                    RunObject = Page "Posted Whse. Receipt List";
                    RunPageLink = "Whse. Receipt No." = FIELD("No.");
                    RunPageView = SORTING("Whse. Receipt No.");
                    ToolTip = 'View the quantity that has been posted as received.';
                }
            }
            group("&Line")
            {
                Caption = '&Line';
                Image = Line;
                action(Card)
                {
                    ApplicationArea = Warehouse;
                    Caption = 'Card';
                    Image = EditLines;
                    ShortCutKey = 'Shift+F7';
                    ToolTip = 'View or change detailed information about the record on the document or journal line.';

                    trigger OnAction()
                    begin
                        PAGE.Run(PAGE::"Warehouse Receipt", Rec);
                    end;
                }
            }
        }
    }

    var
        EstadoOption: Option Abierto,Lanzado,Registrado,Historico,"WR Eliminado";
        EstadoStyle: Text;

    trigger OnAfterGetRecord()
    begin
        ActualizarEstadoTransferencia();
    end;

    trigger OnOpenPage()
    var
        WMSManagement: Codeunit "WMS Management";
    begin
        ErrorIfUserIsNotWhseEmployee;
        FilterGroup(2); // set group of filters user cannot change
        SetFilter("Location Code", WMSManagement.GetWarehouseEmployeeLocationFilter(UserId));
        // Filtrar solo registros que comienzan con "WR" (creados por PITS-RCPT)
        SetFilter("No.", 'WR*');
        FilterGroup(0); // set filter group back to standard
    end;

    local procedure ActualizarEstadoTransferencia()
    var
        PITSLine: Record PITS_WMScd2suc;
    begin
        EstadoOption := EstadoOption::Abierto;
        EstadoStyle := 'Subordinate';

        // Buscar el estado de las líneas PITS asociadas a este WR
        PITSLine.RESET;
        PITSLine.SETCURRENTKEY("FSN Warehouse Receipt No.", "FSN TransferHistorico");
        PITSLine.SETRANGE("FSN Warehouse Receipt No.", "No.");
        PITSLine.SetLoadFields("FSN Warehouse Receipt No.", "FSN TransferHistorico");
        if PITSLine.FINDFIRST then begin
            EstadoOption := PITSLine."FSN TransferHistorico";

            case EstadoOption of
                EstadoOption::Abierto:
                    EstadoStyle := 'None';
                EstadoOption::Lanzado:
                    EstadoStyle := 'StandardAccent';
                EstadoOption::Registrado:
                    EstadoStyle := 'Attention';
                EstadoOption::Historico:
                    EstadoStyle := 'Favorable';
                EstadoOption::"WR Eliminado":
                    EstadoStyle := 'Unfavorable';
            end;
        end;
    end;
}


