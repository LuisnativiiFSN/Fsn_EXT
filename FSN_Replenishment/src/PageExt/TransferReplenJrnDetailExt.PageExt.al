pageextension 50074 "FSN TransferReplenJrnDetExt" extends "LSC Transf Replen. Jrnl Det."
{
    layout
    {
        addafter("Location Name")
        {
            field("Purch. Quantity"; QtyPurch)
            {
                ApplicationArea = all;
                Style = Strong;
                trigger OnValidate()
                var
                    Item_l: Record Item;
                    UOM: Record "Item Unit of Measure";
                    ReplenTemplate: Record "LSC Replen. Template";
                    ReplenCalculation: Codeunit "LSC Replen. Calculation";
                    IsLocationLevelAggregation: Boolean;
                    ReplenishmentJournalLines: Record "LSC Replen. Journal Lines";
                    NewQtyBase: Decimal;
                begin
                    NewQtyBase := QtyPurch;

                    if Item_l.Get(Rec."Item No.") then
                        if UOM.Get(Item_l."No.", Item_l."Purch. Unit of Measure") then
                            NewQtyBase := QtyPurch * UOM."Qty. per Unit of Measure";

                    Rec.Validate(Rec.Quantity, NewQtyBase);
                end;
            }
            field("UOM Purch."; UOMPurch)
            {
                ApplicationArea = all;
                Editable = false;
                StyleExpr = StyleExp;
            }
        }
    }

    actions
    {
    }
    trigger OnAfterGetRecord()
    var
        Item_l: Record Item;
        UOM: Record "Item Unit of Measure";
    begin
        StyleExp := 'None';
        Clear(UOMPurch);
        Clear(QtyPurch);
        if Item_l.Get(Rec."Item No.") then begin
            UOMPurch := Item_l."Purch. Unit of Measure";
            if UOM.Get(Item_l."No.", Item_l."Purch. Unit of Measure") then
                QtyPurch := Rec.Quantity / UOM."Qty. per Unit of Measure"
            else
                QtyPurch := Rec.Quantity;
        end;
        if QtyPurch mod 1 <> 0 then
            StyleExp := 'Unfavorable';
    end;


    var
        UOMPurch: Code[10];
        QtyPurch: Decimal;
        StyleExp: Text[20];

}