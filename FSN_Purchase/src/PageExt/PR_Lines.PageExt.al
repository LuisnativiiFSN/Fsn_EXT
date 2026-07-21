pageextension 50034 "FSN Picking/Receiving Line" extends "LSC Picking/Receiving Lines"
{
    layout
    {

        addafter("ASN Delivery Doc. Line No.")
        {
            field("Total Line Include VAT"; GetTotalLineIncludeVAT(Rec)) { }
        }

        modify("Unit of Measure Code")
        {
            Editable = false;
        }
        modify("Qty. Difference")
        {
            Editable = IsCostEdit;
        }
        addafter("Unit of Measure Code")
        {
            field("FSN Cost"; CostFsn)
            {
                Caption = 'FSN Costo';
                DecimalPlaces = 0 : 5;
                Editable = IsCostEdit;
                trigger OnValidate()
                var
                    header: Record "LSC P/R Counting Header";
                    PurchaseHeader: Record "Purchase Header";
                    purchaseLine: Record "Purchase Line";
                    diference: Decimal;
                    PRConfirm: Codeunit "LSC Picking/Receiving Confirm";
                    Text000: Label 'Costo no puede exceder mas $0.03';
                begin
                    if header.Get(Rec."Document No.") then begin
                        PurchaseHeader.Reset();
                        PurchaseHeader.SetCurrentKey("Document Type", "No.");
                        PurchaseHeader.SetRange(PurchaseHeader."Document Type", PurchaseHeader."Document Type"::Order);
                        PurchaseHeader.SetRange(PurchaseHeader."No.", header."Reference No.");
                        if PurchaseHeader.FindFirst() then begin
                            PurchaseHeader.Status := PurchaseHeader.Status::Open;
                            PurchaseHeader.Modify(true);

                            purchaseLine.Reset();
                            purchaseLine.SetRange("Document No.", header."Reference No.");
                            purchaseLine.SetRange("No.", Rec."Item No.");
                            if purchaseLine.FindSet() then begin

                                diference := CostFsn - purchaseLine."Direct Unit Cost";

                                if Abs(CostFsn - purchaseLine."FSN Direct Unit Cost") >= 0.03 then begin
                                    CostFsn := purchaseLine."FSN Direct Unit Cost";
                                    Message(Text000);
                                end else begin
                                    purchaseLine.Validate("Direct Unit Cost", Abs(CostFsn));
                                    purchaseLine.Modify(true);
                                end;
                            end;

                            PurchaseHeader.Status := PurchaseHeader.Status::Released;
                            PurchaseHeader.Modify(true);
                            Rec."FSN Revisar Costo" := false;
                            //UpdatePageReceip(Rec."Document No.");
                            CalculateTotals();
                            CurrPage.Update();

                        end;
                    end;
                end;
            }
            field("FSN Revisar Costo"; Rec."FSN Revisar Costo")
            {
                Caption = 'Revisar Costo';
                Editable = false;
            }
            field("FSN Escaneo Pendiente"; Rec."FSN Escaneo Pendiente")
            {
                Caption = 'Escaneo Pendiente';
                Editable = false;
            }
        }
        addbefore(Barcode)
        {
            field("FSN Orden Facturado"; Rec."FSN Orden Facturado")
            {
                Caption = 'Orden Facturado';

            }
        }
        modify(Barcode)
        {
            Visible = false;
        }
        addafter(Control1)
        {
            grid(GridTotalLine)
            {
                group(TotalesLine)
                {
                    Caption = 'Totales';
                    field(SubTotalLine; PRHeader."Subtotal")
                    {
                        Caption = 'Subtotal';
                        DrillDown = false;
                        Editable = false;
                    }
                    field(VATLine; PRHeader."Tax")
                    {
                        Caption = 'IVA';
                        Editable = false;
                        ToolTip = 'Specifies the sum of VAT amounts on all lines in the document.';
                    }
                    field(TotalLine; PRHeader."Total")
                    {
                        Caption = 'Total';
                        Editable = false;
                        ToolTip = 'Specifies the sum of the value in the Line Amount Incl. VAT field on all lines in the document minus any discount amount in the Invoice Discount Amount field.';
                    }
                }
                group("ConfirmarTotalesLine")
                {
                    Caption = 'Confirmar Totales';
                    field(ConfirmarSubTotalLine; ConfirmarSubtotal)
                    {
                        Caption = 'Subtotal';
                        Editable = IsEditable;
                        trigger OnValidate()
                        begin
                            if not PRHeader.Get(PRHeader."No.") then
                                exit;
                            PRHeader.ConfirmarSubTotal := ConfirmarSubtotal;
                            PRHeader.Modify(true);
                            CurrPage.Update(true);
                        end;
                    }
                    field(ConfirmarTaxLine; ConfirmarTx)
                    {
                        Caption = 'IVA';
                        Editable = IsEditable;
                        trigger OnValidate()
                        begin
                            if not PRHeader.Get(PRHeader."No.") then
                                exit;
                            PRHeader.ConfirmarTax := ConfirmarTx;
                            PRHeader.Modify(true);
                            CurrPage.Update(true);
                        end;

                    }
                    field(ConfirmarTotalLine; ConfirmarTotal)
                    {
                        Caption = 'Total';
                        Editable = IsEditable;
                        trigger OnValidate()
                        begin
                            if not PRHeader.Get(PRHeader."No.") then
                                exit;
                            PRHeader.ConfirmarTotal := ConfirmarTotal;
                            PRHeader.Modify(true);
                            CurrPage.Update(true);
                        end;
                    }
                }
            }
        }
    }

    actions
    {
        addlast(Processing)
        {

            action(LinesDte)
            {
                ApplicationArea = All;
                Caption = 'Ver Lineas DTE ';
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;
                Image = DocumentsMaturity;
                trigger OnAction()
                var
                begin
                    //LinesDTe;
                    Rec.SetFilter("FSN Orden Facturado", '<>0');
                end;
            }
        }
    }


    procedure UpdatePageReceip(DocumentNo: Code[20])
    var
        PRLines: Record "LSC Picking / Receiving lines";
        purchaseLine: Record "Purchase Line";
        subTotalBase, vatBase, TotalBase : Decimal;
        IUM: Record "Item Unit of Measure";

    begin
        if not PRHeader.Get(PRHeader."No.") then
            exit;
        PRLines.Reset();
        PRLines.SetRange("Document No.", PRHeader."No.");
        PRLines.SetFilter(Quantity, '>%1', 0);
        if PRLines.FindSet() then
            repeat
                purchaseLine.Reset();
                purchaseLine.SetRange("Document No.", PRHeader."Reference No.");
                purchaseLine.SetRange("No.", PRLines."Item No.");
                if purchaseLine.FindFirst() then begin
                    if IUM.Get(purchaseLine."No.", purchaseLine."Unit of Measure Code") then begin
                        if PRLines."Unit of Measure Code" <> purchaseLine."Unit of Measure Code" then begin
                            TotalBase += purchaseLine."Direct Unit Cost" * (PRLines.Quantity / IUM."Qty. per Unit of Measure") + ((purchaseLine."Direct Unit Cost" * (PRLines.Quantity / IUM."Qty. per Unit of Measure")) * (purchaseLine."VAT %" / 100));
                            subTotalBase += purchaseLine."Direct Unit Cost" * (PRLines.Quantity / IUM."Qty. per Unit of Measure");
                            vatBase += ((purchaseLine."Direct Unit Cost" * (PRLines.Quantity / IUM."Qty. per Unit of Measure")) * (purchaseLine."VAT %" / 100));
                        end else begin
                            TotalBase += purchaseLine."Direct Unit Cost" * (PRLines.Quantity) + ((purchaseLine."Direct Unit Cost" * (PRLines.Quantity)) * (purchaseLine."VAT %" / 100));
                            subTotalBase += purchaseLine."Direct Unit Cost" * (PRLines.Quantity);
                            vatBase += ((purchaseLine."Direct Unit Cost" * (PRLines.Quantity)) * (purchaseLine."VAT %" / 100));
                        end;

                    end else
                        Error(Text001, purchaseLine."No.");
                end;
            until PRLines.Next = 0;
        //if ((Round(PRHeader.Total, 3) - Round(TotalBase, 3)) <> 0) or ((Round(PRHeader.Tax, 3) - Round(vatBase, 3)) <> 0) or ((Round(PRHeader.SubTotal, 3) - Round(subTotalBase, 3)) <> 0) then begin
        //    if ((PRHeader.Total - TotalBase) > 1.0) OR ((TotalBase - PRHeader.Total) > 1.0) then begin

        PRHeader."Subtotal" := subTotalBase;
        PRHeader."Tax" := vatBase;
        PRHeader."Total" := TotalBase;
        PRHeader.Modify();
        Commit();
        //    end;
        //end;
    end;

    #region Triggers

    trigger OnAfterGetRecord()
    begin
        IsCostEdit := True;
        if PRHeader.Get(Rec."Document No.") then begin
            IsEditable := true;
            if PRHeader."FSN Automatic Search" then
                IsEditable := false;
            /* Se confirma con William que si el campo EmiteDTE=true, entonces la busquedaAutomatica=true y desactiva manipulacion de totales
                if PRHeader."FSN DTE Manual" then
                    IsEditable := true
                else
                    IsEditable := false;
            */

            if PRHeader."FSN Authorized Reception" then begin
                IsCostEdit := false;
                IsEditable := false;
            end;

        end;
        Clear(CostFsn);
        CostFsn := GetCost(Rec);
    end;

    trigger OnAfterGetCurrRecord()
    begin
        CalculateTotals();
        IsCostEdit := True;
        if PRHeader.Get(Rec."Document No.") then
            if PRHeader."FSN Authorized Reception" then
                IsCostEdit := false;
    end;

    trigger OnModifyRecord(): Boolean
    begin
        //CalsTotalsModManual();
        CalculateTotals();
        //Validate("FSN Cost");
        //UpdatePageReceip(Rec."Document No.");
        exit(true);
    end;

    trigger OnDeleteRecord(): Boolean
    begin
        //CalculateTotals();
        exit(true);
    end;

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    begin
        //CalculateTotals();
        exit(true);
    end;

    local procedure GetCost(PRLines: Record "LSC Picking / Receiving lines"): Decimal
    var
        header: Record "LSC P/R Counting Header";
        purchaseLine: Record "Purchase Line";
    begin
        if not header.Get(PRLines."Document No.") then
            exit(0);
        purchaseLine.SetRange("Document No.", header."Reference No.");
        purchaseLine.SetRange("No.", PRLines."Item No.");
        if not purchaseLine.FindSet() then
            exit(0);
        exit(purchaseLine."Direct Unit Cost");
    end;

    #endregion
    local procedure GetTotalLineIncludeVAT(PRLines: Record "LSC Picking / Receiving lines"): Decimal
    var
        header: Record "LSC P/R Counting Header";
        purchaseLine: Record "Purchase Line";
        total: Decimal;
        IUM: Record "Item Unit of Measure";
        Text003: Label 'El producto %1 no tiene unidad de medida';
    begin
        if not header.Get(PRLines."Document No.") then
            exit(0);
        purchaseLine.SetRange("Document No.", header."Reference No.");
        purchaseLine.SetRange("No.", PRLines."Item No.");
        if not purchaseLine.FindSet() then
            exit(0);
        if IUM.Get(purchaseLine."No.", purchaseLine."Unit of Measure Code") then begin
            if PRLines."Unit of Measure Code" <> purchaseLine."Unit of Measure Code" then
                total += purchaseLine."Direct Unit Cost" * (PRLines.Quantity / IUM."Qty. per Unit of Measure") + ((purchaseLine."Direct Unit Cost" * (PRLines.Quantity / IUM."Qty. per Unit of Measure")) * (purchaseLine."VAT %" / 100))
            else
                total += purchaseLine."Direct Unit Cost" * (PRLines.Quantity) + ((purchaseLine."Direct Unit Cost" * (PRLines.Quantity)) * (purchaseLine."VAT %" / 100));
        end else
            Error(Text003, purchaseLine."No.");
        exit(total);
    end;

    local procedure LineTotal(PRLines: Record "LSC Picking / Receiving lines"): Decimal
    var
        header: Record "LSC P/R Counting Header";
        purchaseLine: Record "Purchase Line";
    begin
        if not header.Get(PRLines."Document No.") then
            exit(0);
        purchaseLine.SetRange("Document No.", header."Reference No.");
        purchaseLine.SetRange("No.", PRLines."Item No.");
        if not purchaseLine.FindSet() then
            exit(0);

        exit(purchaseLine."Direct Unit Cost" * PRLines.Quantity);
    end;

    local procedure LineTax(PRLines: Record "LSC Picking / Receiving lines"): Decimal
    var
        header: Record "LSC P/R Counting Header";
        purchaseLine: Record "Purchase Line";
    begin
        if not header.Get(PRLines."Document No.") then
            exit(0);
        purchaseLine.SetRange("Document No.", header."Reference No.");
        purchaseLine.SetRange("No.", PRLines."Item No.");
        if not purchaseLine.FindSet() then
            exit(0);

        exit((purchaseLine."Direct Unit Cost" * PRLines.Quantity) * (purchaseLine."VAT %" / 100));
    end;

    local procedure LinesDTe()
    var
        PRLines: Record "LSC Picking / Receiving lines";
    begin
        PRLines.Reset();
        PRLines.SetRange("Document No.", Rec."Document No.");
        PRLines.SetFilter("FSN Orden Facturado", '%1', 0);
        if PRLines.FindSet() then
            PRLines.DeleteAll();
        CurrPage.Update(true);
    end;

    procedure CalculateTotals()
    var
        PRLines: Record "LSC Picking / Receiving lines";
        purchaseLine: Record "Purchase Line";
        subTotalBase, vatBase, TotalBase : Decimal;
        IUM: Record "Item Unit of Measure";
        Currency: Record Currency;
        PurchHeader: Record "Purchase Header";
        DirectUnitCost: Decimal;
    begin
        if not PRHeader.Get(Rec."Document No.") then
            exit;
        if not PurchHeader.Get(PurchHeader."Document Type"::Order, PRHeader."Reference No.") then
            exit;

        if PurchHeader."Currency Code" = '' then
            Currency.InitRoundingPrecision
        else
            Currency.Get(PurchHeader."Currency Code");

        PRLines.Reset();
        PRLines.SetRange("Document No.", PRHeader."No.");
        PRLines.SetFilter(Quantity, '>%1', 0);
        if PRLines.FindSet() then
            repeat
                purchaseLine.Reset();
                purchaseLine.SetRange("Document No.", PRHeader."Reference No.");
                purchaseLine.SetRange("No.", PRLines."Item No.");
                if purchaseLine.FindFirst() then begin
                    DirectUnitCost := purchaseLine."Direct Unit Cost";
                    if IUM.Get(purchaseLine."No.", purchaseLine."Unit of Measure Code") then begin
                        if PRLines."Unit of Measure Code" <> purchaseLine."Unit of Measure Code" then begin
                            //TotalBase += DirectUnitCost * (PRLines.Quantity / IUM."Qty. per Unit of Measure") + (DirectUnitCost * (PRLines.Quantity / IUM."Qty. per Unit of Measure")) * (purchaseLine."VAT %" / 100);
                            subTotalBase += Round(DirectUnitCost * (PRLines.Quantity / IUM."Qty. per Unit of Measure"), Currency."Invoice Rounding Precision", Currency.InvoiceRoundingDirection);
                            vatBase += (DirectUnitCost * (PRLines.Quantity / IUM."Qty. per Unit of Measure")) * (purchaseLine."VAT %" / 100);
                        end else begin
                            //TotalBase += DirectUnitCost * (PRLines.Quantity) + (DirectUnitCost * (PRLines.Quantity)) * (purchaseLine."VAT %" / 100);
                            subTotalBase += Round(DirectUnitCost * (PRLines.Quantity), Currency."Invoice Rounding Precision", Currency.InvoiceRoundingDirection);
                            vatBase += (DirectUnitCost * (PRLines.Quantity)) * (purchaseLine."VAT %" / 100);
                        end;

                    end else
                        Error(Text001, purchaseLine."No.");
                end;
            until PRLines.Next = 0;
        ConfirmarSubtotal := PRHeader.ConfirmarSubTotal;
        ConfirmarTx := PRHeader.ConfirmarTax;
        ConfirmarTotal := PRHeader.ConfirmarTotal;

        PRHeader."Subtotal" := subTotalBase;//Round(, Currency."Invoice Rounding Precision", Currency.InvoiceRoundingDirection);
        PRHeader."Tax" := vatBase;//Round(vatBase, Currency."Invoice Rounding Precision", Currency.InvoiceRoundingDirection);
        PRHeader."Total" := subTotalBase + vatBase;//Round(TotalBase, Currency."Invoice Rounding Precision", Currency.InvoiceRoundingDirection);
        PRHeader.Modify(true);
        Commit();


    end;

    var
        CostFsn: Decimal;
        PRHeader: Record "LSC P/R Counting Header";
        IsEditable: Boolean;
        IsCostEdit: Boolean;
        Text001: Label 'El producto %1 no tiene unidad de medida';

        ConfirmarTotal, ConfirmarSubtotal, ConfirmarTx : Decimal;



}