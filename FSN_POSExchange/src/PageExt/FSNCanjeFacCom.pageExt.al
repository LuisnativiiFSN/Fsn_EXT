pageextension 50144 "FSN Canje Purch line" extends "Sales Invoice Subform"
{
    layout
    {
        // Add changes to page layout here
    }

    actions
    {
        // Add changes to page actions here
        addafter(DocAttach)
        {
            action("Canjes")
            {
                Image = ChangeBatch;
                trigger OnAction()
                begin
                    RunCange();
                end;
            }
        }

    }

    var
        myInt: Integer;
        ProdList: Text;
        SalesHeader: Record "Sales Header";
        RecCodeunit: Codeunit SelectionFilterManagement;
        Messag: Label 'Debe agregar numero de DTE';

    local procedure RunCange()
    var
        CanjePage: Page "FSN POS Exchange Released";
        CanjeTable: Record "FSN POS Exchange Transaction";
        CanjeTmp, CanjeTmp2 : Record "FSN POS Exchange Transaction" temporary;
        SelectionFilterRec: Text;
        TempRecRef: RecordRef;
        Arr_Item: array[1000000] of Code[20];
        Arr_Recibo: array[1000000] of Code[20];
        Arr_Line: array[1000000] of Code[20];
    begin
        if Rec.FindLast() then;
        SalesHeader.Reset();
        SalesHeader.SetRange("No.", Rec."Document No.");
        if (SalesHeader.FindFirst()) then begin
            if (SalesHeader."External Document No." = '') then begin
                Message(Messag);
                exit;
            end;
            Clear(CanjePage);
            Clear(CanjeTable);
            CanjePage.LookupMode := true;
            CanjeTpvFilter(CanjeTable, CanjeTmp);
            CanjePage.SetTableView(CanjeTable);
            if CanjePage.RunModal() = Action::LookupOK then begin
                CanjePage.SetSelectionFilter(CanjeTable);
                TempRecRef.GetTable(CanjeTable);
                GetSelectionFilter(TempRecRef, 30, Arr_Item, Arr_Recibo, Arr_Line);
                InsertCanje(Arr_Item, Arr_Recibo, Arr_Line);
                RecalcCanje();
            end;
        end;
    end;


    procedure RecalcCanje()
    var
        SalesHeader: Record "Sales Header";
        CanjeTable: Record "FSN POS Exchange Transaction";
        SalesLine: Record "Sales Line";
    begin
        if Rec.FindLast() then;
        SalesLine.SetRange("Document No.", Rec."Document No.");
        SalesLine.CalcSums("Amount Including VAT");
        SalesHeader.Reset();
        SalesHeader.SetRange("No.", Rec."Document No.");
        if SalesHeader.Find('-') then begin
            CanjeTable.Reset();
            CanjeTable.SetRange("External Document No.", SalesHeader."No.");
            if CanjeTable.Find('-') then begin
                repeat
                    CanjeTable."Amount Doc. Inc. VAT" := SalesLine."Amount Including VAT";
                    CanjeTable.Modify(true);
                until CanjeTable.Next() = 0;
            end;
        end;
    end;

    local procedure InsertCanje(Arr_Item: array[1000000] of Code[20];
        Arr_Recibo: array[1000000] of Code[20];
         Arr_Line: array[1000000] of Code[20])
    var
        xToInt, xInt, Line : Integer;
        SalesLine, SalesLineVAT : Record "Sales Line";
        CanjeTable: Record "FSN POS Exchange Transaction";
        SHeader: Record "Sales Header";
        Item: Record "Item";
        UML: Record "Item Unit of Measure";
    begin
        if SHeader.get(Rec."Document Type", Rec."Document No.") then;
        xToInt := ArrayLen(Arr_Recibo);
        for xInt := 1 to xToInt do begin
            if Arr_Item[xInt] <> '' then begin
                if not SalesLine.get(Rec."Document Type", rec."Document No.", rec."Line No.") then
                    SalesLine := Rec;
                CanjeTable.Reset();
                CanjeTable.SetRange("Item No.", Arr_Item[xInt]);
                CanjeTable.SetRange("Receipt No.", Arr_Recibo[xInt]);
                if Evaluate(Line, Arr_Line[xInt]) then
                    CanjeTable.SetRange("Line No.", Line);
                CanjeTable.SetFilter("Transaction No.", '<>%1', 0);
                if CanjeTable.FindFirst() then begin
                    if not ValidateLineExt(SHeader, Arr_Item[xInt], CanjeTable) then begin
                        SalesLine.AddItem(SalesLine, Arr_Item[xInt]);
                        SalesLine.Validate("Location Code", 'CANJES');
                        SalesLine.Validate("Unit of Measure", CanjeTable."Unit of Measure");
                        SalesLine.Validate(Quantity, CanjeTable.Quantity);
                        SalesLine.Modify(true);
                    end;
                    CanjeTable.Status := CanjeTable.Status::"Request Liquidate CN";
                    CanjeTable."External Document No." := SalesHeader."No.";
                    SalesLineVAT.Reset();
                    SalesLineVAT.SetRange("Document No.", Rec."Document No.");
                    SalesLineVAT.CalcSums("VAT Base Amount");
                    CanjeTable."Amount Doc. Inc. VAT" := SalesLineVAT."VAT Base Amount";
                    CanjeTable.Modify(true);
                end;
                Rec := SalesLine;
                Commit();
            end;
        end;
    end;

    procedure ValidateLineExt(var SalesHeader: Record "Sales Header";
        Item: Code[20];
        var CanjeTable: Record "FSN POS Exchange Transaction"): Boolean
    var
        Sline: Record "Sales Line";
    begin
        Sline.Reset();
        Sline.SetRange("Document No.", SalesHeader."No.");
        Sline.SetRange("No.", Item);
        if Sline.FindFirst() then begin
            Sline.Validate(Quantity, Sline.Quantity + CanjeTable.Quantity);
            Sline.Validate("Unit of Measure Code", CanjeTable."Unit of Measure");
            Sline.Modify(true);
            exit(true);
        end else
            exit(false);
    end;

    procedure CanjeTpvFilter(var CanjeTable: Record "FSN POS Exchange Transaction"; var CanjeTmp: Record "FSN POS Exchange Transaction" temporary)
    var
        myInt: Integer;
        Item_l: Record "Item";
        Vendor_l: Record "Vendor";
        CanjeTable1: Record "FSN POS Exchange Transaction";
        SelectionFilter, SelectionFilterItem : Text;
        number: Integer;
    begin

        SalesHeader.Reset();
        SalesHeader.SetRange("No.", Rec."Document No.");
        if SalesHeader.FindFirst() then;
        CanjeTable1.Reset();
        CanjeTable1.SetRange(Status, CanjeTable1.Status::"Exit Applied");
        CanjeTable1.SetFilter("Transaction No.", '<>%1', 0);
        if CanjeTable1.Find('-') then
            repeat
                IF CanjeTable1."Item No." <> '' THEN BEGIN
                    IF Item_l.GET(CanjeTable1."Item No.") THEN BEGIN
                        IF Item_l."Vendor No." <> '' THEN
                            IF Vendor_l.GET(Item_l."Vendor No.") THEN
                                if DelChr(Vendor_l."Name", '=', '.') = DelChr(SalesHeader."Bill-to Name", '=', '.') then begin
                                    SelectionFilter += '|' + CanjeTable1."Receipt No.";
                                    SelectionFilterItem += '|' + CanjeTable1."Item No.";
                                    number := number + 1;
                                end;
                    end;
                end;
            until (CanjeTable1.Next() = 0) or (number = 2000);
        SelectionFilter := CopyStr(SelectionFilter, 2);
        SelectionFilterItem := CopyStr(SelectionFilterItem, 2);
        SalesHeader.SetRange("No.", Rec."Document No.");
        if SalesHeader.FindFirst() then;
        CanjeTable.Reset();
        CanjeTable.SetRange(Status, CanjeTable.Status::"Exit Applied");
        CanjeTable.SetRange("External Document No.", '');
        CanjeTable.SetFilter("Receipt No.", SelectionFilter);
        CanjeTable.SetFilter("Item No.", SelectionFilterItem);
        CanjeTable.SetFilter("Transaction No.", '<>%1', 0);
    end;

    procedure GetSelectionFilter(var TempRecRef: RecordRef; SelectionFieldID: Integer; var Arr_Item: array[1000000] of Code[20]; var Arr_Recibo: array[1000000] of Code[20]; var Arr_Line: array[1000000] of Code[20]): Text
    var
        RecRef: RecordRef;
        FieldRef: FieldRef;
        FirstRecRef: Text;
        LastRecRef: Text;
        SelectionFilter: Text;
        SavePos: Text;
        TempRecRefCount: Integer;
        More: Boolean;
        Number: Integer;
        xToInt, xInt : Integer;
    begin
        if TempRecRef.IsTemporary then begin
            RecRef := TempRecRef.Duplicate;
            RecRef.Reset();
        end else
            RecRef.Open(TempRecRef.Number);
        xInt := 0;

        TempRecRefCount := TempRecRef.Count();
        if TempRecRefCount > 0 then begin
            xToInt := TempRecRefCount;
            TempRecRef.Ascending(true);
            TempRecRef.Find('-');
            while TempRecRefCount > 0 do begin
                if xInt >= 0 then
                    xInt := xInt + 1;
                TempRecRefCount := TempRecRefCount - 1;
                RecRef.SetPosition(TempRecRef.GetPosition);
                RecRef.Find;
                FieldRef := RecRef.Field(SelectionFieldID);
                Arr_Item[xInt] := Format(FieldRef.Value);
                SelectionFilter := Format(FieldRef.Value);
                FieldRef := RecRef.Field(10);
                Arr_Recibo[xInt] := Format(FieldRef.Value);
                FieldRef := RecRef.Field(20);
                Arr_Line[xInt] := Format(FieldRef.Value);
                LastRecRef := FirstRecRef;
                More := TempRecRefCount > 0;
                while More do
                    if RecRef.Next() = 0 then
                        More := false
                    else begin
                        SavePos := TempRecRef.GetPosition;
                        TempRecRef.SetPosition(RecRef.GetPosition);
                        if not TempRecRef.Find then begin
                            More := false;
                            TempRecRef.SetPosition(SavePos);
                        end else begin
                            FieldRef := RecRef.Field(SelectionFieldID);
                            if xInt < xToInt then
                                xInt := xInt + 1;
                            SelectionFilter += '||' + Format(FieldRef.Value);
                            Arr_Item[xInt] := Format(FieldRef.Value);
                            FieldRef := RecRef.Field(10);
                            Arr_Recibo[xInt] := Format(FieldRef.Value);
                            FieldRef := RecRef.Field(20);
                            Arr_Line[xInt] := Format(FieldRef.Value);
                            TempRecRefCount := TempRecRefCount - 1;
                            if TempRecRefCount = 0 then
                                More := false;
                        end;
                    end;
                if TempRecRefCount > 0 then
                    TempRecRef.Next;
            end;
            exit(SelectionFilter);
        end;
    end;
}
