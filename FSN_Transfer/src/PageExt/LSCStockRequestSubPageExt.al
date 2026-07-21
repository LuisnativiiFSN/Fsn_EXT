pageextension 50031 "FSN Stock Request Subform" extends "LSC Stock Request Subform"
{
    layout
    {
        addbefore("Item No.")
        {
            field("FSN Barcode No."; Rec."FSN Barcode No.")
            {
                trigger OnValidate()
                var
                    Barcodes2: Record "LSC Barcodes";
                    Item2: Record Item;
                begin
                    if Barcodes2.Get(Rec."FSN Barcode No.") then begin
                        Rec.Validate("Item No.", Barcodes2."Item No.");
                        Rec.Validate("Unit of Measure Code", Barcodes2."Unit of Measure Code");
                        Rec."FSN Barcode No." := Barcodes2."Barcode No.";
                        if Item2.Get(Rec."Item No.") then
                            Rec."FSN Attrib 1 Code" := Item2."LSC Attrib 1 Code";
                    end;
                end;
            }
        }

        addbefore(Description)
        {
            field("FSN Attrib 1 Code"; Rec."FSN Attrib 1 Code")
            {
            }
        }

        addafter("Unit of Measure Code")
        {
            field(ValInventory; ValInventory)
            {
                Editable = false;
                StyleExpr = StyleStatusText;
                Caption = 'Inventory';
            }
        }

        addafter(ValInventory)
        {
            field(QuantityMax; QuantityMax)
            {
                Editable = false;
                Caption = 'Politica Maxima';
            }
        }

        addafter(QuantityMax)
        {
            field(QuantityMin; QuantityMin)
            {
                Editable = false;
                Caption = 'Politica Minima';
            }
        }

        addafter(QuantityMin)
        {
            field(QuantityTranfer; QuantityTranfer)
            {
                Editable = false;
                Caption = 'Cantidad Transferencia';
            }
        }

        addafter(QuantityTranfer)
        {
            field(QuantityPurchase; QuantityPurchase)
            {
                Editable = false;
                Caption = 'Cantidad Compra';
            }
        }
        // Add changes to page layout here
    }

    actions
    {
        // Add changes to page actions here
    }

    var
        myInt: Integer;
        QuantityMax: Decimal;
        QuantityMin: Decimal;
        QuantityTranfer: Decimal;
        QuantityPurchase: Decimal;
        FSNUtility: Codeunit "FSN Utility";
        ValInventory: Decimal;
        StyleStatusText: Text;
        StyleStatus: Option None,Standard,StandardAccent,Strong,StrongAccent,Attention,AttentionAccent,Favorable,Unfavorable,Ambiguous,Subordinate;


    /*trigger OnInsertRecord()
    var
        Item2: Record Item;
        Barcodes2: Record "LSC Barcodes";
    begin
        if Item2.Get(Rec."Item No.") then begin
            if (rec."FSN Barcode No." = '') or (Rec."Unit of Measure Code" = '') then begin
                Rec."FSN Attrib 1 Code" := Item2."LSC Attrib 1 Code";

                Barcodes2.Reset();
                Barcodes2.SetRange("Item No.", Rec."Item No.");
                Barcodes2.SetRange("Unit of Measure Code", Item2."Purch. Unit of Measure");
                if Barcodes2.FindFirst() then begin
                    Rec.Validate("Unit of Measure Code", Barcodes2."Unit of Measure Code");
                    Rec."FSN Barcode No." := Barcodes2."Barcode No.";
                end;
            end;
        end;
    end;*/

    trigger OnModifyRecord(): boolean
    var
        Item2: Record Item;
    begin
        if (Rec."Item No." <> '') and Item2.Get(Rec."Item No.") then
            Rec."FSN Attrib 1 Code" := Item2."LSC Attrib 1 Code";

        ValidateInventory(ValInventory, Rec);
    end;

    trigger OnAfterGetRecord()
    var
        Item2: Record Item;
        PurchaseLine: Record "Purchase Line";
        TransferHeader: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
        StockHeader: Record "LSC InStore Stock Req. Header";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: Boolean;
        MsgResult: Text;
        Barcodes2: Record "LSC Barcodes";
    begin

        QuantityPurchase := 0;

        IF StockHeader.GET("Document No.") THEN BEGIN
            PurchaseLine.RESET;
            PurchaseLine.SETRANGE(PurchaseLine."Location Code", StockHeader."Store No.");
            PurchaseLine.SETRANGE(PurchaseLine."Document Type", PurchaseLine."Document Type"::Order);
            PurchaseLine.SETRANGE(PurchaseLine."No.", "Item No.");
            IF PurchaseLine.FIND('-') THEN BEGIN
                REPEAT
                    QuantityPurchase := QuantityPurchase + PurchaseLine.Quantity;
                UNTIL PurchaseLine.NEXT() = 0;
            END;

            QuantityTranfer := 0;

            TransferLine.RESET;
            TransferLine.SETRANGE(TransferLine."Item No.", "Item No.");
            TransferLine.SETRANGE(TransferLine."Transfer-to Code", StockHeader."Store No.");
            TransferLine.SETRANGE(TransferLine."Derived From Line No.", 0);
            TransferLine.CALCSUMS(Quantity);
            QuantityTranfer := QuantityTranfer + TransferLine.Quantity;


            QuantityMax := 0;
            QuantityMin := 0;

            Clear(PosMenuLineTemp);

            //Se utiliza FSNREPLENSTOREITEM para consultar la data de los campos extendidos FSN MAXIMUN Y FSN MINIMUN 
            //de la tabla LSC Replen. Item Store Rec en la extension FSN Replenishment
            RequestID := 'FSNREPLENSTOREITEM';
            PosMenuLineTemp."Menu ID" := Rec."Item No.";
            PosMenuLineTemp."POS Help ID" := StockHeader."Store No.";
            FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
            IF XMLRequest <> '' THEN
                EVALUATE(QuantityMax, XMLRequest);
            IF XMLResponse <> '' THEN
                EVALUATE(QuantityMin, XMLResponse);
        END;

        ValidateInventory(ValInventory, Rec);
    end;

    local procedure ValidateInventory(var DecimalRead: Decimal; RequestLines: Record "LSC InStore Stock Req. Line")
    var
        Item: Record Item;
        InventoryLevel: Record "FSN WMS Levels";
        RecordExists: Boolean;
    begin

        Clear(RecordExists);
        Clear(DecimalRead);
        if RequestLines.Quantity = 0 then begin
            DecimalRead := 0;
            RecordExists := true;
            exit
        end;

        if Item.Get(RequestLines."Item No.") then;

        if InventoryLevel.Get(RequestLines."Item No.") then begin
            DecimalRead := InventoryLevel.InventoryCD;
            ProStyleStutus(DecimalRead, RequestLines);
            RecordExists := true;
            exit;
        end;
    end;

    procedure ProStyleStutus(ValQ: Decimal; RequestLines: Record "LSC InStore Stock Req. Line")
    var
        myInt: Integer;
    begin
        if not (RequestLines.Quantity > ValQ) then
            StyleStatusText := Format(StyleStatus::Favorable)
        else
            StyleStatusText := Format(StyleStatus::Unfavorable);
    end;

}