page 50033 "FSN POS Exch. Analisis Track"
{
    PageType = List;
    SourceTable = "FSN Global Table Temporary";
    SourceTableTemporary = true;
    ApplicationArea = All;
    UsageCategory = Administration;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field(Code20_1; Code20_1)
                {
                    Caption = 'ItemNo';
                }
                field(Code10_1; Code10_1)
                {
                    Caption = 'Unit Of Measure';
                }
                field(Code10_2; Code10_2)
                {
                    Caption = 'StoreNo';
                }
                field(Int_1; Int_1)
                {
                    Caption = 'Quantity';

                    trigger OnValidate()
                    begin
                        Int_2 := Int_1;
                    end;
                }
                field(GetItemDescriptionByUM; GetItemDescriptionByUM(Code20_1, Code10_1))
                {
                    Caption = 'Description';
                }
                field(GetStoreName; GetStoreName(Code10_2))
                {
                    Caption = 'Tienda Nombre';
                }
                field(Int_2; Int_2)
                {
                    Caption = 'Balance';
                }
                field(Int_3; Int_3)
                {
                    Caption = 'Relations';
                }
                field(Counter1; Counter1)
                {
                    Caption = 'Track';
                }
                field(Date_1; Date_1)
                {
                    Caption = 'Ending Date Search';
                }
            }
        }
    }

    actions
    {
        area(processing)
        {
            action("Search Relations")
            {
                Caption = 'Search Relations';
                Image = MapDimensions;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                var
                    POSExchTrans: Record "FSN POS Exchange Transaction";
                    POSExchAnalisysResult: Page "FSN POS Exch. Analisys Result";
                    RemainingQty: Integer;
                    lText001: Label 'Status is not "Exit Applied"';
                    CountTrack: Integer;
                    TextStatus: Text[75];
                    POSExchTransTemp: Record "FSN POS Exchange Transaction" temporary;
                    TemporaryTableArr: array[1000, 14] of Text[50];
                    TemporaryTableCount: Integer;
                begin
                    POSExchTransTemp.RESET;
                    POSExchTransTemp.DELETEALL;

                    Rec.RESET;

                    IF Rec.FINDFIRST THEN
                        POSExchAnalisysResult.DeleteTracks();
                    TemporaryTableCount := 1;
                    REPEAT
                        RemainingQty := Rec.Int_1;
                        CountTrack := 0;

                        Rec.Int_2 := Rec.Int_1;
                        Rec.Int_3 := 0;

                        POSExchTrans.RESET;
                        POSExchTrans.SETCURRENTKEY("Item No.", "Unit of Measure", "Store No.", "Transaction Date", Quantity);
                        POSExchTrans.SETRANGE(POSExchTrans."Item No.", Rec.Code20_1);
                        IF Rec.Code10_1 <> '' THEN
                            POSExchTrans.SETRANGE(POSExchTrans."Unit of Measure", Rec.Code10_1);
                        POSExchTrans.SETRANGE(POSExchTrans."Store No.", Rec.Code10_2);
                        IF Rec.Date_1 <> 0D THEN BEGIN
                            POSExchTrans.SETFILTER(POSExchTrans."Transaction Date", '<=%1', Rec.Date_1);
                            POSExchTrans.ASCENDING(FALSE);
                        END ELSE
                            POSExchTrans.ASCENDING(TRUE);

                        IF POSExchTrans.FINDFIRST AND (RemainingQty <> 0) THEN
                            REPEAT
                                TextStatus := '';
                                IF NOT (POSExchTrans.Status IN [POSExchTrans.Status::"Exit Applied",
                                                                //POSExchTrans.Status::"Liquidate Product",
                                                                POSExchTrans.Status::"Liquidate CreditNote"]) THEN
                                    TextStatus := lText001;

                                IF (POSExchTrans.Quantity <= RemainingQty) AND NOT POSExchTransTemp.GET(POSExchTrans."Receipt No.",
                                                                                    POSExchTrans."Transaction No.",
                                                                                    POSExchTrans."Line No.",
                                                                                    POSExchTrans."Store No.",
                                                                                    POSExchTrans."POS Terminal No.") THEN BEGIN
                                    POSExchTransTemp := POSExchTrans;
                                    POSExchTransTemp.INSERT();

                                    //POSExchAnalisysResult.InsertTrack(POSExchTrans,(TextStatus <> ''),Counter1,FALSE,TextStatus);
                                    TemporaryTableArr[TemporaryTableCount] [1] := POSExchTrans."Receipt No.";
                                    TemporaryTableArr[TemporaryTableCount] [2] := FORMAT(POSExchTrans."Transaction No.");
                                    TemporaryTableArr[TemporaryTableCount] [3] := FORMAT(POSExchTrans."Line No.");
                                    TemporaryTableArr[TemporaryTableCount] [4] := POSExchTrans."Store No.";
                                    TemporaryTableArr[TemporaryTableCount] [5] := POSExchTrans."POS Terminal No.";
                                    TemporaryTableArr[TemporaryTableCount] [6] := POSExchTrans."Item No.";
                                    TemporaryTableArr[TemporaryTableCount] [7] := POSExchTrans."Unit of Measure";
                                    TemporaryTableArr[TemporaryTableCount] [8] := FORMAT(POSExchTrans.Quantity);
                                    TemporaryTableArr[TemporaryTableCount] [9] := FORMAT(POSExchTrans."Transaction Date");
                                    TemporaryTableArr[TemporaryTableCount] [10] := COPYSTR(TextStatus, 1, 75);
                                    IF (TextStatus <> '') THEN
                                        TemporaryTableArr[TemporaryTableCount] [11] := '1'
                                    ELSE
                                        TemporaryTableArr[TemporaryTableCount] [11] := '0';
                                    TemporaryTableArr[TemporaryTableCount] [12] := '0';
                                    TemporaryTableArr[TemporaryTableCount] [13] := FORMAT(Rec.Counter1);
                                    TemporaryTableArr[TemporaryTableCount] [14] := FORMAT(POSExchTrans.Status);
                                    TemporaryTableCount += 1;
                                    CountTrack += 1;
                                    RemainingQty := RemainingQty - POSExchTrans.Quantity;
                                    /*
                                      TemporaryTable.INIT();
                                      TemporaryTable.Code20_1 := POSExchTrans."Receipt No.";
                                      TemporaryTable.Int_1:= POSExchTrans."Transaction No.";
                                      TemporaryTable.Int_3 := POSExchTrans."Line No.";
                                      TemporaryTable.Code10_1 := POSExchTrans."Store No.";
                                      TemporaryTable.Code10_2 := POSExchTrans."POS Terminal No.";
                                      TemporaryTable.Code20_2 := POSExchTrans."Item No.";
                                      TemporaryTable.Code10_3 := POSExchTrans."Unit of Measure";
                                      TemporaryTable.Int_2 := POSExchTrans.Quantity;
                                      TemporaryTable.Date_1 := POSExchTrans."Transaction Date";
                                      TemporaryTable."Message Process" := TextStatus;
                                      TemporaryTable.Bool_1 := (TextStatus <> '');
                                      TemporaryTable.Bool_2 := FALSE;
                                      TemporaryTable.Counter1 := Rec.Counter1;
                                      TemporaryTable.INIT();
                                    */
                                END;

                            UNTIL (POSExchTrans.NEXT = 0) OR (RemainingQty = 0);
                        IF CountTrack <> 0 THEN BEGIN
                            Rec.Int_3 := CountTrack;
                            Rec.Int_2 := RemainingQty;
                            Rec.MODIFY;
                        END;
                    UNTIL Rec.NEXT = 0;
                    COMMIT;

                    IF TemporaryTableCount = 1 THEN
                        EXIT;

                    POSExchAnalisysResult.InitArray(TemporaryTableArr, TemporaryTableCount);
                    POSExchAnalisysResult.LOOKUPMODE(TRUE);
                    POSExchAnalisysResult.RUNMODAL();

                end;
            }
        }
    }

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    begin
        KeysConunt += 1;
        Counter1 := KeysConunt;
    end;

    var
        KeysConunt: Integer;
}

