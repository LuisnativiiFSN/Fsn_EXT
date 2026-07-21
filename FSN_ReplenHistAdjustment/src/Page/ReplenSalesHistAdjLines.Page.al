page 50043 "Replen. Sales Hist. Adj. Lines"
{
    Caption = 'FSN Replen. Sales Hist. Adj. Lines';
    DelayedInsert = true;
    PageType = List;
    SourceTable = "FSN Replen. Sales Adj. Line";
    ApplicationArea = all;
    UsageCategory = Administration;


    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("Barcode No."; Rec."Barcode No.")
                {
                    TableRelation = "LSC Barcodes"."Barcode No.";

                    trigger OnValidate()
                    var
                        Barcodes: Record "LSC Barcodes";
                        Item: Record "Item";
                        BCode: Code[22];
                        BarcodeMgmt: Codeunit "LSC Barcode Management";
                        Amount: Decimal;
                        Qty: Decimal;
                        POSSESION: Codeunit "LSC POS Session";
                    begin
                        BCode := '';
                        BCode := "Barcode No.";
                        Rec.Date := TODAY;
                        Rec.StaffID := POSSESION.StaffID();
                        Rec."Location Code" := POSSESION.StoreLocation();

                        IF BarcodeMgmt.FindBarcodeDetails(BCode, Item, Barcodes, Amount, Qty) THEN BEGIN
                            IF Item.GET(Barcodes."Item No.") THEN BEGIN
                                Rec."Item No." := Item."No.";
                                Rec.Description := Item.Description;
                                Rec."Unit of Measure" := Barcodes."Unit of Measure Code";  //CSMQ140117
                                tmpThis.RESET;
                                tmpThis.SETRANGE("Item No.", Rec."Item No.");
                                tmpThis.SETRANGE("Location Code", Rec."Location Code");
                                tmpThis.SETRANGE(Date, Date);
                                IF tmpThis.FINDLAST THEN
                                    Rec."Line No." := tmpThis."Line No." + 10000
                                ELSE
                                    Rec."Line No." := 10000;

                                Rec."Barcode No." := BCode;
                            END
                            ELSE
                                MESSAGE(Text003 + Barcodes."Item No.");
                        END
                        ELSE
                            MESSAGE(Text004);
                    end;
                }
                field("Line No."; Rec."Line No.")
                {
                    Editable = false;
                }
                field("Item No."; Rec."Item No.")
                {
                }
                field(Description; Rec.Description)
                {
                    Editable = false;
                }
                field(Date; Date)
                {
                    Editable = false;
                }
                field(Quantity; Rec.Quantity)
                {

                    trigger OnValidate()
                    var
                        varQuantity: Integer;
                        prevQuantity: Integer;
                    begin
                        IF NOT CONFIRM('Seguro que desea introducir la cantidad de \ \' + FORMAT(Quantity, 0, '<Standard,1>') + ' ' + Description + ' \ \en concepto de ajuste de ventas?') THEN
                            Quantity := xRec.Quantity;
                    end;
                }
                field("Unit of Measure"; Rec."Unit of Measure")
                {
                }
                field(StaffID; REc.StaffID)
                {
                    Editable = false;
                }
                field("Location Code"; Rec."Location Code")
                {
                    Editable = false;
                }
            }
        }
    }

    actions
    {
    }

    trigger OnClosePage()
    var
        reopen: Boolean;
    begin
        UpdateQty;
    end;

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    begin
        IF Item2.GET(Rec."Item No.") THEN BEGIN
            ReplenishmentSalesHistoryAdj.RESET;
            ReplenishmentSalesHistoryAdj.SETRANGE("Item No.", Rec."Item No.");
            ReplenishmentSalesHistoryAdj.SETRANGE("Location Code", Rec."Location Code");
            ReplenishmentSalesHistoryAdj.SETRANGE(Date, Date);
            IF ReplenishmentSalesHistoryAdj.ISEMPTY THEN BEGIN
                ReplenishmentSalesHistoryAdj.INIT;
                ReplenishmentSalesHistoryAdj."Item No." := Rec."Item No.";
                ReplenishmentSalesHistoryAdj."Variant Code" := Rec."Variant Code";
                ReplenishmentSalesHistoryAdj."Location Code" := Rec."Location Code";
                ReplenishmentSalesHistoryAdj.Date := Date;
                ReplenishmentSalesHistoryAdj."Division Code" := Item2."LSC Division Code";
                ReplenishmentSalesHistoryAdj."Item Category Code" := Item2."Item Category Code";
                ReplenishmentSalesHistoryAdj.INSERT(TRUE);
                COMMIT;
            END;
        END;
        //ReplenSalesHistoryAdjPage.adjustQuantity;
        MESSAGE('Ajuste de Ventas realizado correctamente!');
    end;

    trigger OnModifyRecord(): Boolean
    begin
        IF Item2.GET(Rec."Item No.") THEN BEGIN
            ReplenishmentSalesHistoryAdj.RESET;
            ReplenishmentSalesHistoryAdj.SETRANGE("Item No.", Rec."Item No.");
            ReplenishmentSalesHistoryAdj.SETRANGE("Location Code", Rec."Location Code");
            ReplenishmentSalesHistoryAdj.SETRANGE(Date, Rec.Date);
            IF ReplenishmentSalesHistoryAdj.ISEMPTY THEN BEGIN
                ReplenishmentSalesHistoryAdj.INIT;
                ReplenishmentSalesHistoryAdj."Item No." := Rec."Item No.";
                ReplenishmentSalesHistoryAdj."Variant Code" := Rec."Variant Code";
                ReplenishmentSalesHistoryAdj."Location Code" := Rec."Location Code";
                ReplenishmentSalesHistoryAdj.Date := Rec.Date;
                ReplenishmentSalesHistoryAdj."Division Code" := Item2."LSC Division Code";
                ReplenishmentSalesHistoryAdj."Item Category Code" := Item2."Item Category Code";
                ReplenishmentSalesHistoryAdj.INSERT(TRUE);
                COMMIT;
            END;

            IF (Rec."Item No." <> xRec."Item No.") OR
            (Rec."Barcode No." <> xRec."Barcode No.") OR
            (Rec.Quantity <> xRec.Quantity) OR
            (Rec."Unit of Measure" <> xRec."Unit of Measure") THEN
                MESSAGE('Ajuste de Ventas realizado correctamente!');
        END;
    end;

    var
        reopen: Boolean;
        ReplenishmentSalesHistoryAdj: Record "LSC Replen. Sales Hist. Adj.";
        ItemUOM: Record "Item Unit of Measure";
        ReplenSalesHistoryAdjPage: Page "LSC Replen. Sales Hist. Adj.";
        Text003: Label 'Barcode found\item not found =';
        Text004: Label 'Barcode not found';
        tmpThis: Record "FSN Replen. Sales Adj. Line";

        Item2: Record "Item";
        SalesAdjustmentC: Codeunit "FSN SalesAdjustment";

    procedure UpdateQty()
    begin
        SalesAdjustmentC.adjustQuantity("Location Code", Date, "Item No.");
    end;
}

