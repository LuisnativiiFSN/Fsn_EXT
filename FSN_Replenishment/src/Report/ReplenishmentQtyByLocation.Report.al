report 50005 "FSN Full Replen. By Location"
{
    ApplicationArea = All;
    UsageCategory = Administration;
    DefaultLayout = RDLC;
    Caption = 'FSN Full Replen. By Location';
    RDLCLayout = 'src\Report\Layout\ReplenishmentQtyByLocation.rdl';
    PreviewMode = Normal;

    dataset
    {
        dataitem(Replen_Jrnl_Details; "LSC Replen. Jrnl. Details")
        {
            dataitem(LocationSplit; Integer)
            {
                DataItemTableView = SORTING(Number) WHERE(Number = FILTER(1 .. 2));

                column(Item_No; Replen_Jrnl_Details."Item No.")
                {
                    IncludeCaption = true;
                }
                column(Description; Replen_Jrnl_Details.Description)
                {
                    IncludeCaption = true;
                }
                column(Vendor_Name; Replen_Jrnl_Details."Vendor Name")
                {
                    IncludeCaption = true;
                }
                column(Location_Code; LocationCodeOut)
                {
                }
                column(Location_Name; LocationNameOut)
                {
                }
                column(Quantity; QuantityOut)
                {
                    //IncludeCaption = true;
                }
                column(Consolidated_No; Consolidated_No)
                {
                }
                column(QuantityPurch; QuantityOut)
                {

                }
                /*dataitem(Purchase_Price; "Purchase Price")
                {
                    DataItemLinkReference = Replen_Jrnl_Details;
                    DataItemLink = "Item No." = FIELD("Item No."),
                                   "Vendor No." = FIELD("Vendor No.");
                    column(Last_Direct_Cost; Purchase_Price."Direct Unit Cost")
                    {
                    }

                    dataitem(Item1; Item)
                    {
                        DataItemLinkReference = Replen_Jrnl_Details;
                        DataItemLink = "No." = FIELD("Item No.");

                        column(Attrib_1_Code; Item1."LSC Attrib 1 Code")
                        {
                        }
                        column(Barra; Item1."FSN Barcode No.")
                        {
                        }
                        column(NoNivelCD; Item1."FSN Warehouse Level")
                        {
                        }
                    }
                }*/
                column(Attrib_1_Code; Item_g."LSC Attrib 1 Code")
                {
                }
                column(Barra; Item_g."FSN Barcode No.")
                {
                }
                column(NoNivelCD; Item_g."FSN Warehouse Level")
                {
                }
                column(Last_Direct_Cost; UnitCostOut)
                {
                }


                column(UOM; JrnLine."Unit of Measure Code")
                {
                }
                column(Cost_Amount; CostAmountOut)
                {

                }
                column(VendorItemNo; ItemVend."Vendor Item No.")
                {
                }

                trigger OnAfterGetRecord()
                var
                    IsExtraF13Row: Boolean;
                    IsRobotItem: Boolean;
                begin
                    IsExtraF13Row := Number = 2;
                    if IsExtraF13Row and (Replen_Jrnl_Details."Location Code" <> 'F13') then begin
                        CurrReport.Skip;
                        exit;
                    end;

                    IsRobotItem := false;
                    if Replen_Jrnl_Details."Location Code" = 'F13' then
                        IsRobotItem := IsRobotF13Item(Replen_Jrnl_Details."Item No.");

                    if IsExtraF13Row then begin
                        LocationCodeOut := CopyStr(Replen_Jrnl_Details."Location Code" + '-R', 1, MaxStrLen(LocationCodeOut));
                        LocationNameOut := 'ROBOT';
                        if IsRobotItem then begin
                            QuantityOut := QuantityPurch;
                            UnitCostOut := UnitCost;
                            CostAmountOut := JrnLine."Cost Amount";
                        end else begin
                            QuantityOut := 0;
                            UnitCostOut := 0;
                            CostAmountOut := 0;
                        end;
                    end else begin
                        LocationCodeOut := Replen_Jrnl_Details."Location Code";
                        LocationNameOut := GetLocationName(Replen_Jrnl_Details."Location Code");
                        if IsRobotItem then begin
                            QuantityOut := 0;
                            UnitCostOut := 0;
                            CostAmountOut := 0;
                        end else begin
                            QuantityOut := QuantityPurch;
                            UnitCostOut := UnitCost;
                            CostAmountOut := JrnLine."Cost Amount";
                        end;
                    end;
                end;
            }

            trigger OnAfterGetRecord()
            var
                ToPurchPrice: Record "Purchase Price";
                l_itemUOM: Record "Item Unit of Measure";
            begin
                Clear(QuantityPurch);
                if (JrnLine."Line No." <> Replen_Jrnl_Details."Line No.") or (Replen_Jrnl_Details."Line No." = 0) then
                    JrnLine.Get(Replen_Jrnl_Details."Replenishment Template Code", Replen_Jrnl_Details."Batch No.",
                        Replen_Jrnl_Details."Line No.");

                if Replen_Jrnl_Details."Item No." <> Item_g."No." then begin
                    Item_g.Get(Replen_Jrnl_Details."Item No.");
                    if Item_g."Purch. Unit of Measure" = '' then
                        Item_g."Purch. Unit of Measure" := Item_g."Base Unit of Measure";
                    itemUOM.Get(Item_g."No.", Item_g."Purch. Unit of Measure");
                    UnitCost := 0;

                    ToPurchPrice.SetRange("Item No.", Item_g."No.");
                    ToPurchPrice.SetRange("Vendor No.", JrnLine."Vendor No.");
                    ToPurchPrice.SetFilter("Ending Date", '%1|>=%2', 0D, Today);
                    ToPurchPrice.SetRange("Variant Code", '');
                    ToPurchPrice.SetRange("Starting Date", 0D, Today);
                    ToPurchPrice.SetRange("Currency Code", '');
                    ToPurchPrice.SetFilter("Unit of Measure Code", '%1|%2', Item_g."Purch. Unit of Measure", '');
                    if ToPurchPrice.Find('-') then
                        UnitCost := ToPurchPrice."Direct Unit Cost"
                    else
                        UnitCost := Item_g."Last Direct Cost" * itemUOM."Qty. per Unit of Measure";
                end;

                if itemUOM."Qty. per Unit of Measure" = 0 then
                    itemUOM."Qty. per Unit of Measure" := 1;
                QuantityPurch := Replen_Jrnl_Details.Quantity / itemUOM."Qty. per Unit of Measure";
                //Replen_Jrnl_Details.Quantity := Replen_Jrnl_Details.Quantity * itemUOM."Qty. per Unit of Measure";


                IF Consolidated_No = '' THEN BEGIN
                    if ReplenTemp_g.Get(Replen_Jrnl_Details."Replenishment Template Code") then
                        if ReplenTemp_g."FSN Consolidate No." <> '' then
                            Consolidated_No := ReplenTemp_g."FSN Consolidate No.";
                END;
                ItemVend.Reset();
                ItemVend.SetRange("Item No.", Replen_Jrnl_Details."Item No.");
                ItemVend.SetRange("Vendor No.", JrnLine."Vendor No.");
                if ItemVend.FindFirst() then;
            end;
        }
    }

    requestpage
    {

        layout
        {
        }

        actions
        {
        }
    }

    labels
    {
    }

    local procedure IsRobotF13Item(ItemNo: Code[20]): Boolean
    var
        ItemSpecialGroupLink: Record "LSC Item/Special Group Link";
    begin
        ItemSpecialGroupLink.SetRange("Item No.", ItemNo);
        ItemSpecialGroupLink.SetRange("Special Group Code", 'ROBOTF13');
        exit(ItemSpecialGroupLink.FindFirst());
    end;

    local procedure GetLocationName(LocationCode: Code[10]): Text[100]
    var
        Store: Record "LSC Store";
    begin
        if Store.Get(LocationCode) then
            exit(Store.Name)
        else
            exit(LocationCode);
    end;

    var
        ReplenTemp_g: Record "LSC Replen. Template";
        Item_g: Record Item;
        itemUOM: Record "Item Unit of Measure";
        RpshJrnlLines: Record "LSC Replen. Journal Lines";
        JrnLine: Record "LSC Replen. Journal Lines";
        "Consolidated_No": Code[20];
        QuantityPurch: Decimal;
        UnitCost: Decimal;
        PrecalcCost: Decimal;
        ItemVend: Record "Item Vendor";
        LocationCodeOut: Code[10];
        LocationNameOut: Text[100];
        QuantityOut: Decimal;
        UnitCostOut: Decimal;
        CostAmountOut: Decimal;
}

