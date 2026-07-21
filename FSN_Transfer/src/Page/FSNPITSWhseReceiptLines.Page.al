page 50121 "FSN PITS Whse Receipt Lines"
{
    PageType = ListPart;
    SourceTable = PITS_WMScd2suc;
    Caption = 'Líneas PITS';
    UsageCategory = Lists;
    ApplicationArea = Warehouse;
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(content)
        {
            repeater(Lines)
            {
                field("No."; "No.")
                {
                    ApplicationArea = Warehouse;
                    ToolTip = 'Número de Transferencia (TR)';
                }
                field("Line No."; "Line No.")
                {
                    ApplicationArea = Warehouse;
                    ToolTip = 'Número de línea PITS';
                }
                field("Item No."; "Item No.")
                {
                    ApplicationArea = Warehouse;
                    ToolTip = 'Código del artículo';
                }
                field(Description; Description)
                {
                    ApplicationArea = Warehouse;
                    ToolTip = 'Descripción del artículo';
                }
                field(Quantity; Quantity)
                {
                    ApplicationArea = Warehouse;
                    ToolTip = 'Cantidad solicitada';
                }
                field("Qty. to Ship"; "Qty. to Ship")
                {
                    ApplicationArea = Warehouse;
                    ToolTip = 'Cantidad a enviar';
                }

                field("FSN Quantity Scan"; "FSN Quantity Scan")
                {
                    ApplicationArea = Warehouse;
                    ToolTip = 'Cantidad Escaneada';
                    Style = Unfavorable; // este es el estilo rojo
                    StyleExpr = StyleTxt;
                    Visible = IsSalesmachine;
                }

                field("Unit of Measure"; "Unit of Measure")
                {
                    ApplicationArea = Warehouse;
                    ToolTip = 'Unidad de medida';
                }
                field("Transfer-to Code"; "Transfer-to Code")
                {
                    ApplicationArea = Warehouse;
                    ToolTip = 'Ubicación de destino';
                }
                field("Starting Date"; "Starting Date")
                {
                    ApplicationArea = Warehouse;
                    ToolTip = 'Fecha de inicio';
                }
                field("Ending Date"; "Ending Date")
                {
                    ApplicationArea = Warehouse;
                    ToolTip = 'Fecha final';
                }
                field("No. Pedido"; "No. Pedido")
                {
                    ApplicationArea = Warehouse;
                    ToolTip = 'Número de pedido EBS';
                }
            }
        }
    }

    var
        FilterWR: Code[20];

    procedure SetFilterByWR(pWR: Code[20])
    begin
        FilterWR := pWR;
        ApplyFilters();
    end;

    local procedure ApplyFilters()
    begin
        Rec.RESET;
        if FilterWR <> '' then
            Rec.SETRANGE("FSN Warehouse Receipt No.", FilterWR);
        Rec.SETFILTER("Qty. to Ship", '>0');
        Rec.SETFILTER(Quantity, '>0');
    end;

    trigger OnOpenPage()
    begin
        ApplyFilters();
    end;

    trigger OnAfterGetRecord()
    begin

        Param.Reset();
        Param.SetRange(Grupo, 'ROBOTSTORE');
        Param.SetRange(Codigo, "Transfer-to Code");
        IF Param.FindFirst() then begin
            if Param.Activo then begin
                IsSalesmachine := true;
                if "FSN Quantity Scan" < Quantity then
                    StyleTxt := 'Unfavorable' // rojo
                else
                    StyleTxt := 'Favorable'; // verde
            end else
                IsSalesmachine := false;
        end else
            IsSalesmachine := false;
    end;

    procedure ValidateMachine(IsM: Boolean)
    var
    begin
        IsSalesmachine := IsM;
    end;

    var
        IsRed: Boolean;
        StyleTxt: Text;
        IsSalesmachine: Boolean;
        Param: Record "FSN Parameter";
}
