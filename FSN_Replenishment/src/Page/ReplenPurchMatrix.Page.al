page 50044 "FSN Replen. By Location"
{
    Caption = 'Items by Location';
    DeleteAllowed = false;
    InsertAllowed = false;
    LinksAllowed = false;
    PageType = Card;
    SaveValues = true;
    SourceTable = "LSC Replen. Journal Lines";

    layout
    {
        area(content)
        {
            group(Options)
            {
                Caption = 'Options';
                fixed("Matrix")
                {
                    group("Replen. Template")
                    {
                        field("Replenishment Template Code"; "Replenishment Template Code")
                        {
                        }
                        field(MATRIX_CaptionRange; MATRIX_CaptionRange)
                        {
                            Caption = 'Column Set';
                        }
                        field(ShowColumnName; ShowColumnName)
                        {
                            Caption = 'Show Column Name';

                            trigger OnValidate()
                            begin
                                ShowColumnNameOnAfterValidate;
                            end;
                        }
                    }
                    group("Warehouse")
                    {
                        field(WarehouseStoreReplenishm; WarehouseStoreReplenishm)
                        {
                            Caption = 'Repl. Type';
                            Importance = Promoted;
                        }
                        field(ReplLocation; ReplenishmentLocation.Code)
                        {
                            Caption = 'Repl. Location';
                            Importance = Promoted;
                            Lookup = true;
                            Visible = ReplLocationVisible;
                        }
                        field(ReplName; ReplenishmentLocation.Name)
                        {
                            Caption = 'Repl. Name';
                            Visible = ReplLocationVisible;
                        }
                    }
                }
            }
            part(MatrixSubPage; "FSN Replen. By Location Matrix")
            {
                SubPageLink = "Replenishment Template Code" = FIELD(FILTER("Replenishment Template Code"));
            }
        }
    }

    actions
    {
        area(processing)
        {
            group("Nagivate")
            {
                action("Previous Set")
                {
                    Caption = 'Previous Set';
                    Image = PreviousSet;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;
                    ToolTip = 'Previous Set';

                    trigger OnAction()
                    begin
                        SetColumns(MATRIX_SetWanted::Previous);
                        UpdateMatrixSubform;
                    end;
                }
                action("Next Set")
                {
                    Caption = 'Next Set';
                    Image = NextSet;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;
                    ToolTip = 'Next Set';

                    trigger OnAction()
                    begin
                        SetColumns(MATRIX_SetWanted::Next);
                        UpdateMatrixSubform;
                    end;
                }
            }
            separator("Space")
            {
            }
            group("Report")
            {
                action("Quick Report")
                {
                    Image = Report2;
                    Promoted = true;
                    PromotedCategory = Process;
                    RunPageMode = View;

                    trigger OnAction()
                    var
                        ReportJrnDetails: Record "LSC Replen. Jrnl. Details";
                        ReplenTemplate: Record "LSC Replen. Template";
                    begin
                        ReportJrnDetails.RESET;
                        ReportJrnDetails.SETRANGE("Replenishment Template Code", "Replenishment Template Code");
                        ReplenTemplate.Get("Replenishment Template Code");
                        if IsSalaReplenReport(ReplenTemplate) then
                            REPORT.RUNMODAL(REPORT::"FSN Full Replen. By Loc. Sala", TRUE, FALSE, ReportJrnDetails)
                        else
                            REPORT.RUNMODAL(REPORT::"FSN Full Replen. By Location", TRUE, FALSE, ReportJrnDetails);
                        //ShowFilters
                    end;
                }
            }
        }
    }

    trigger OnOpenPage()
    var
        ReplenCalculationl: Codeunit "LSC Replen. Calculation";
        ItemUnitofMeasure: Record "Item Unit of Measure";
        Item_l: Record Item;
        ReplenJrnLine_l: Record "LSC Replen. Journal Lines";
    begin
        SetColumns(MATRIX_SetWanted::Initial);
        TempItemTable.RESET;
        TempItemTable.SetRange(TempItemTable."Replenishment Template Code", "Replenishment Template Code");
        TempItemTable.DELETEALL;

        ReplenJrnLine_l.RESET;
        ReplenJrnLine_l.SetRange("Replenishment Template Code", "Replenishment Template Code");
        if ReplenJrnLine_l.Find('-') then
            repeat
                ReplenJrnLine_l.CalcFields("Vendor Name");
                if not Item_l.Get(ReplenJrnLine_l."Item No.") then begin
                    Clear(Item_l);
                    Clear(ItemUnitofMeasure);
                end
                else
                    if not ItemUnitofMeasure.Get(Item_l."No.", Item_l."Purch. Unit of Measure") then begin
                        Clear(ItemUnitofMeasure);
                        ItemUnitofMeasure."Qty. per Unit of Measure" := 1;
                    end else
                        if ItemUnitofMeasure."Qty. per Unit of Measure" > 1 then
                            ReplenJrnLine_l.Quantity := Round(ReplenJrnLine_l.Quantity / ItemUnitofMeasure."Qty. per Unit of Measure", 1);


                TempItemTable.INIT;
                TempItemTable."Replenishment Template Code" := ReplenJrnLine_l."Replenishment Template Code";
                TempItemTable."Batch No." := ReplenJrnLine_l."Batch No.";
                TempItemTable."Line No." := ReplenJrnLine_l."Line No.";
                TempItemTable."Barcode No." := Item_l."FSN Barcode No.";
                TempItemTable."Item No." := ReplenJrnLine_l."Item No.";
                TempItemTable.Description := ReplenJrnLine_l.Description;
                TempItemTable."Direct Unit Cost" := ReplenCalculationl.FindDirectUnitCost(Item_l, ItemUnitofMeasure, ReplenJrnLine_l."Vendor No.", '', ReplenJrnLine_l.Quantity);
                TempItemTable."Vendor No." := ReplenJrnLine_l."Vendor No.";
                TempItemTable."Vendor Name" := ReplenJrnLine_l."Vendor Name";
                TempItemTable."Attrib 1 Code" := Item_l."LSC Attrib 1 Code";
                TempItemTable."Qty. per Unit of Measure" := ItemUnitofMeasure."Qty. per Unit of Measure";
                TempItemTable."Purc. Unit of Measure" := Item_l."Purch. Unit of Measure";
                TempItemTable.INSERT;
            until ReplenJrnLine_l.Next() = 0;
        UpdateMatrixSubform;
    end;

    var
        MatrixRecord: Record "Location";
        MatrixRecords: array[32] of Record "Location";
        MatrixRecordRef: RecordRef;
        MATRIX_SetWanted: Option Initial,Previous,Same,Next;
        ShowColumnName: Boolean;
        MATRIX_CaptionSet: array[32] of Text[1024];
        MATRIX_CaptionRange: Text[100];
        MATRIX_PKFirstRecInCurrSet: Text[100];
        MATRIX_CurrSetLength: Integer;
        MatrixLines: Record "LSC Replen. Jrnl. Details";
        TempItemTable: Record "FSN Replen. Template Matrix";
        ReplenishmentTemplate_g: Record "LSC Replen. Template";
        WarehouseStoreReplenishm: Option " ","Replenishment for a Warehouse","Replenishment for Stores";
        ReplenishmentLocation: Record "Location";
        ReplLocationVisible: Boolean;


    procedure SetColumns(SetWanted: Option Initial,Previous,Same,Next)
    var
        CaptionFieldNo: Integer;
        CurrentMatrixRecordOrdinal: Integer;
    begin

        CLEAR(MATRIX_CaptionSet);
        CLEAR(MatrixRecords);
        CurrentMatrixRecordOrdinal := 1;

        ReplenishmentTemplate_g.RESET;
        ReplenishmentTemplate_g.SETRANGE(Code, "Replenishment Template Code");
        ReplenishmentTemplate_g.SETRANGE("Replenishment Type", ReplenishmentTemplate_g."Replenishment Type"::Purchase);
        ReplenishmentTemplate_g.FIND('-');
        CASE ReplenishmentTemplate_g."Purchase Order Type" OF
            ReplenishmentTemplate_g."Purchase Order Type"::"One Purchase Order per Vendor",
            ReplenishmentTemplate_g."Purchase Order Type"::"One Purchase Order per Vendor with Cross Docking":
                BEGIN
                    WarehouseStoreReplenishm := WarehouseStoreReplenishm::"Replenishment for a Warehouse";
                    MatrixRecord.SETRANGE("LSC Location is a Warehouse", TRUE);
                    MatrixRecord.SETRANGE(Code, ReplenishmentTemplate_g."Location Code");
                END;
            ReplenishmentTemplate_g."Purchase Order Type"::"Purchase Orders for Receiving Locations":
                BEGIN
                    WarehouseStoreReplenishm := WarehouseStoreReplenishm::"Replenishment for Stores";
                    MatrixRecord.SETRANGE("LSC Location is a Warehouse", FALSE);
                END;
            ELSE
                WarehouseStoreReplenishm := WarehouseStoreReplenishm::" ";
        END;

        IF ReplenishmentTemplate_g."Location Code" <> '' THEN BEGIN
            ReplenishmentLocation.GET(ReplenishmentTemplate_g."Location Code");
            ReplLocationVisible := TRUE;
        END ELSE BEGIN
            CLEAR(ReplenishmentLocation);
            ReplLocationVisible := FALSE;
        END;

        MatrixRecordRef.GETTABLE(MatrixRecord);
        MatrixRecordRef.SETTABLE(MatrixRecord);

        IF ShowColumnName THEN
            CaptionFieldNo := MatrixRecord.FIELDNO(Name)
        ELSE
            CaptionFieldNo := MatrixRecord.FIELDNO(Code);
        CustomGenerateMatrixData(MatrixRecordRef, SetWanted, (ARRAYLEN(MatrixRecords) / 4), CaptionFieldNo, MATRIX_PKFirstRecInCurrSet,
          MATRIX_CaptionSet, MATRIX_CaptionRange, MATRIX_CurrSetLength);

        IF MATRIX_CurrSetLength > 0 THEN BEGIN
            MatrixRecord.SETPOSITION(MATRIX_PKFirstRecInCurrSet);
            MatrixRecord.FIND;
            REPEAT
                MatrixRecords[CurrentMatrixRecordOrdinal].COPY(MatrixRecord);
                CurrentMatrixRecordOrdinal := CurrentMatrixRecordOrdinal + 4; //Para mostrar correctamente los datos de las Location en sus columnas respectivas
            UNTIL (CurrentMatrixRecordOrdinal > MATRIX_CurrSetLength) OR (MatrixRecord.NEXT <> 1);
        END;
    end;

    local procedure ShowColumnNameOnAfterValidate()
    begin
        SetColumns(MATRIX_SetWanted::Same);
        UpdateMatrixSubform();
    end;

    local procedure ShowInTransitOnAfterValidate()
    begin
        SetColumns(MATRIX_SetWanted::Initial);
    end;


    procedure UpdateMatrixSubform()
    begin

        CurrPage.MatrixSubPage.PAGE.SETRECORD(TempItemTable);

        CurrPage.MatrixSubPage.PAGE.Load(MATRIX_CaptionSet, MatrixRecords, MatrixRecord);
        CurrPage.UPDATE;
    end;

    local procedure IsSalaReplenReport(ReplenTemplate: Record "LSC Replen. Template"): Boolean
    begin
        exit(
            (UpperCase(ReplenTemplate."Location Code") <> 'CD') and
            (ReplenTemplate."Replenishment Type" = ReplenTemplate."Replenishment Type"::Purchase) and
            (ReplenTemplate."Purchase Order Type" = ReplenTemplate."Purchase Order Type"::"Purchase Orders for Receiving Locations"));
    end;

    procedure CustomGenerateMatrixData(var RecRef: RecordRef; SetWanted: Option Initial,Previous,Same,Next,PreviousColumn,NextColumn; MaximumSetLength: Integer; CaptionFieldNo: Integer; var PKFirstRecInCurrSet: Text[1024]; var CaptionSet: array[32] of Text[1024]; var CaptionRange: Text[1024]; var CurrSetLength: Integer)
    var
        Steps: Integer;
        Text001: Label 'The previous column set could not be found.';
    begin
        //CSMQ161115 Funcion generadora de datos por cuartetos
        CLEAR(CaptionSet);
        CaptionRange := '';
        CurrSetLength := 0;

        IF RecRef.ISEMPTY THEN BEGIN
            PKFirstRecInCurrSet := '';
            EXIT;
        END;

        CASE SetWanted OF
            SetWanted::Initial:
                RecRef.FINDFIRST;
            SetWanted::Previous:
                BEGIN
                    RecRef.SETPOSITION(PKFirstRecInCurrSet);
                    RecRef.GET(RecRef.RECORDID);
                    Steps := RecRef.NEXT(-MaximumSetLength);
                    IF NOT (Steps IN [-MaximumSetLength, 0]) THEN
                        ERROR(Text001);
                END;
            SetWanted::Same:
                BEGIN
                    RecRef.SETPOSITION(PKFirstRecInCurrSet);
                    RecRef.GET(RecRef.RECORDID);
                END;
            SetWanted::Next:
                BEGIN
                    RecRef.SETPOSITION(PKFirstRecInCurrSet);
                    RecRef.GET(RecRef.RECORDID);
                    IF NOT (RecRef.NEXT(MaximumSetLength) = MaximumSetLength) THEN BEGIN
                        RecRef.SETPOSITION(PKFirstRecInCurrSet);
                        RecRef.GET(RecRef.RECORDID);
                    END;
                END;
            SetWanted::PreviousColumn:
                BEGIN
                    RecRef.SETPOSITION(PKFirstRecInCurrSet);
                    RecRef.GET(RecRef.RECORDID);
                    Steps := RecRef.NEXT(-1);
                    IF NOT (Steps IN [-1, 0]) THEN
                        ERROR(Text001);
                END;
            SetWanted::NextColumn:
                BEGIN
                    RecRef.SETPOSITION(PKFirstRecInCurrSet);
                    RecRef.GET(RecRef.RECORDID);
                    IF NOT (RecRef.NEXT(1) = 1) THEN BEGIN
                        RecRef.SETPOSITION(PKFirstRecInCurrSet);
                        RecRef.GET(RecRef.RECORDID);
                    END;
                END;
        END;

        PKFirstRecInCurrSet := RecRef.GETPOSITION;

        REPEAT
            CurrSetLength := CurrSetLength + 1;
            CaptionSet[CurrSetLength] := FORMAT(RecRef.FIELD(CaptionFieldNo).VALUE);
            CurrSetLength := CurrSetLength + 1;
            CaptionSet[CurrSetLength] := 'Avg';
            CurrSetLength := CurrSetLength + 1;
            CaptionSet[CurrSetLength] := 'Inv';
            CurrSetLength := CurrSetLength + 1;
            CaptionSet[CurrSetLength] := 'Bon';

        UNTIL (CurrSetLength = MaximumSetLength * 4) OR (RecRef.NEXT <> 1);

        IF CurrSetLength = 1 THEN
            CaptionRange := CaptionSet[1]
        ELSE                                               //CurrSetLength
            CaptionRange := CaptionSet[1] + '..' + CaptionSet[CurrSetLength - 3];
    end;
}

