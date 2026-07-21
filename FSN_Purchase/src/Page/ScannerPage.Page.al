page 50068 "FSN Purch. Receipt by Scanner"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "FSN Global Table Temporary";
    SourceTableTemporary = true;
    Caption = 'Escanear productos Recep. Compra';


    layout
    {
        area(Content)
        {
            group(GroupName)
            {
                Visible = NOT InvDte;
                field(Scanner; Code20_3)
                {
                    Caption = 'Scanner';
                    ApplicationArea = All;
                    trigger OnValidate()
                    var
                        LSCPheader: Record "LSC P/R Counting Header";
                        LSCPickingReceivingLines: Record "LSC Picking / Receiving lines";
                        LSCPickingReceivingLinesExt: Record "LSC Picking / Receiving lines";
                        Item: Record Item;
                        Barcodes: Record "LSC Barcodes";
                        Transfer: Boolean;
                        TransferLine: Record "Transfer Line";
                    begin
                        if not Barcodes.Get(Code20_3) then
                            exit;
                        if not Item.Get(Barcodes."Item No.") then
                            exit;

                        LSCPickingReceivingLines.Reset();
                        LSCPickingReceivingLines.SetRange("Document No.", Code20_1);
                        LSCPickingReceivingLines.SetRange("Item No.", Item."No.");
                        if LSCPickingReceivingLines.find('-') then
                            repeat
                                LSCPickingReceivingLinesExt.Reset();
                                LSCPickingReceivingLinesExt := LSCPickingReceivingLines;
                                if (-LSCPickingReceivingLines."Difference") > 0 then begin
                                    LSCPickingReceivingLines.Validate(Quantity, LSCPickingReceivingLines.Quantity + 1);
                                    LSCPickingReceivingLines."FSN Escaneo Pendiente" := LSCPickingReceivingLinesExt."FSN Escaneo Pendiente";
                                    LSCPickingReceivingLines."FSN Orden Facturado" := LSCPickingReceivingLinesExt."FSN Orden Facturado";
                                    LSCPickingReceivingLines."FSN Revisar Costo" := LSCPickingReceivingLinesExt."FSN Revisar Costo";
                                    LSCPickingReceivingLines."FSN Cantidad DTE" := LSCPickingReceivingLinesExt."FSN Cantidad DTE";
                                    if LSCPickingReceivingLines.Quantity = LSCPickingReceivingLines."FSN Cantidad DTE" then begin
                                        LSCPickingReceivingLines."FSN Escaneo Pendiente" := false;
                                        Message(Txt0);
                                    end;
                                    LSCPickingReceivingLines.Modify(true);
                                end else begin
                                    LSCPheader.Reset();
                                    LSCPheader.SetRange("No.", Code20_1);
                                    if LSCPheader.FindFirst() then
                                        if LSCPheader.Receiving = LSCPheader.Receiving::"Transfer In" then begin
                                            TransferLine.Reset();
                                            TransferLine.SetRange("Document No.", LSCPheader."Reference No.");
                                            TransferLine.SetRange("Line No.", LSCPickingReceivingLines."Line No.");
                                            if TransferLine.FindFirst() then
                                                if LSCPickingReceivingLines."Unit of Measure Code" <> TransferLine."Unit of Measure Code" then
                                                    Error(gText008, TransferLine."Item No.", LSCPickingReceivingLines."Unit of Measure Code")
                                                ELSE
                                                    if (LSCPickingReceivingLines.Quantity) < TransferLine.Quantity then begin
                                                        LSCPickingReceivingLines.Validate(Quantity, LSCPickingReceivingLines.Quantity + 1);
                                                        LSCPickingReceivingLines."FSN Escaneo Pendiente" := LSCPickingReceivingLinesExt."FSN Escaneo Pendiente";
                                                        LSCPickingReceivingLines."FSN Orden Facturado" := LSCPickingReceivingLinesExt."FSN Orden Facturado";
                                                        LSCPickingReceivingLines."FSN Revisar Costo" := LSCPickingReceivingLinesExt."FSN Revisar Costo";
                                                        LSCPickingReceivingLines."FSN Cantidad DTE" := LSCPickingReceivingLinesExt."FSN Cantidad DTE";
                                                        LSCPickingReceivingLines.Modify(true);
                                                    end else begin
                                                        LSCPickingReceivingLines."FSN Escaneo Pendiente" := false;
                                                        LSCPickingReceivingLines.Modify(true);
                                                        Message(Txt0);
                                                    end;

                                        end else begin
                                            LSCPickingReceivingLines."FSN Escaneo Pendiente" := false;
                                            LSCPickingReceivingLines.Modify(true);
                                            Message(Txt0);
                                        end;
                                end;
                            until LSCPickingReceivingLines.Next() = 0
                        else
                            Message(Txt1);
                        Rec.Code20_3 := '';
                    end;
                }
            }
            group(Detail)
            {
                Visible = NOT InvDte;
                part(Lines; "LSC Picking/Receiving Lines")
                {
                    Editable = false;
                    ApplicationArea = All;
                    SubPageLink = "Document No." = FIELD(FILTER(Code20_1));
                }
            }
            group(GScannInvDte)
            {
                Visible = InvDte;
                Caption = 'Escanear';
                field(ScanInvDte; Code20_3)
                {
                    Caption = 'Escaneo';
                    ShowCaption = false;
                    ApplicationArea = All;
                    trigger OnValidate()
                    var
                        LSCPheader: Record "LSC P/R Counting Header";
                        LSCPickingReceivingLines: Record "LSC Picking / Receiving lines";
                        Item: Record Item;
                        Barcodes: Record "LSC Barcodes";
                        Transfer: Boolean;
                        TransferLine: Record "Transfer Line";
                    begin
                        if not Barcodes.Get(Code20_3) then
                            exit;
                        if not Item.Get(Barcodes."Item No.") then
                            exit;

                        LSCPickingReceivingLines.Reset();
                        LSCPickingReceivingLines.SetRange("Document No.", Code20_1);
                        LSCPickingReceivingLines.SetRange("Item No.", Item."No.");
                        LSCPickingReceivingLines.SetRange("FSN Escaneo Pendiente", true);
                        if LSCPickingReceivingLines.FindFirst() then begin
                            LSCPickingReceivingLines."FSN Escaneo Pendiente" := false;
                            LSCPickingReceivingLines.Modify(true);
                        end;
                        Rec.Code20_3 := '';
                    end;

                }
            }
            group(DetailDTE)
            {
                Visible = InvDte;
                Caption = 'Detalle Factura DTE';
                part(LinDte; "LSC Picking/Receiving Lines")
                {
                    Editable = false;
                    ApplicationArea =;
                    SubPageLink = "Document No." = FIELD(FILTER(Code20_1)), "FSN Escaneo Pendiente" = FIELD(FILTER(Bool_1));
                    SubPageView = sorting("FSN Orden Facturado");
                }

            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(BorradoES)
            {
                ApplicationArea = All;
                Visible = Lim;

                trigger OnAction()

                var
                    LSCPickingReceivingLines: Record "LSC Picking / Receiving lines";
                    Item: Record Item;
                    Barcodes: Record "LSC Barcodes";
                begin
                    LSCPickingReceivingLines.Reset();
                    LSCPickingReceivingLines.SetRange("Document No.", Code20_1);
                    if LSCPickingReceivingLines.find('-') then
                        repeat
                            LSCPickingReceivingLines.Validate(Quantity, 0);
                            LSCPickingReceivingLines.Modify(true);
                        until LSCPickingReceivingLines.Next() = 0;
                end;
            }

            action(EscAut)
            {
                ApplicationArea = All;
                Visible = Lim;
                trigger OnAction()
                var
                    LSCPinck: Record "LSC P/R Counting Header";
                    LSCPickingReceivingLines: Record "LSC Picking / Receiving lines";
                    Item: Record Item;
                    Barcodes: Record "LSC Barcodes";
                    purchaseLine: Record "Purchase Line";
                    Transfer: Record "Transfer Line";
                begin

                    if LSCPinck.Get(Code20_1) then begin
                        LSCPickingReceivingLines.Reset();
                        LSCPickingReceivingLines.SetRange("Document No.", Code20_1);
                        if LSCPickingReceivingLines.find('-') then
                            repeat
                                LSCPickingReceivingLines.Validate(Quantity, LSCPickingReceivingLines."Ordered Qty.");
                                LSCPickingReceivingLines.Modify(true);
                            until LSCPickingReceivingLines.Next() = 0;
                    end;
                end;
            }
        }
    }


    trigger OnOpenPage()
    begin
        Param.Reset();
        Param.SetRange(Grupo, 'LIMPIAR');
        Param.SetRange(Codigo, 'DEV03');
        IF Param.FindFirst() AND Param.Activo then
            Lim := true;

        Rec.Reset();
        Rec.DeleteAll(true);
        Rec.Init();
        Rec.Code20_1 := GlobalReceiptNo;
        Rec.Code20_3 := '';
        Rec.Bool_1 := InvDte;
        Rec.Insert();

    end;

    procedure SetPurchOrderNo(pReceipt: Code[20]; InvoiDte: Boolean)
    begin
        GlobalReceiptNo := pReceipt;
        InvDte := InvoiDte;

    end;

    var
        Param: Record "FSN Parameter";
        Lim: Boolean;
        GlobalReceiptNo: Code[20];
        Txt0: Label 'Line completed.';
        Txt1: Label 'Barcode not found';
        gText008: Label 'Unidad de medida a registrar del producto %1 no es correcta, segun el pedido debe ingresar %2';

        InvDte: Boolean;
}