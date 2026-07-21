codeunit 50019 "FSN Sell Out Value Entries"
{

    /*   [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Post Utility", 'OnAfterPostTransactionFiscalProcess', '', true, true)]
       local procedure "LSC POS Post Utility_OnAfterPostTransactionFiscalProcess"
   (
   var TransactionHeader: Record "LSC Transaction Header";
   var FiscalProcessActive: Boolean;
   var FiscalProcessOk: Boolean;
   var POSTransaction: Record "LSC POS Transaction"
   )
       var
           DiscountEntry: Record "LSC Trans. Discount Entry";
           PerDiscount: Record "LSC Periodic Discount";
           PerDiscountLine: Record "LSC Periodic Discount Line";
           SellOutValuesEntries: Record "FSN Sell Out Value Entry";
           CouponHeader: Record "LSC Coupon Header";
           OfferType: Enum "LSC Trans. Disc. Ent Offer Typ";
       begin
           DiscountEntry.Reset();
           DiscountEntry.SetCurrentKey("Store No.", "POS Terminal No.", "Transaction No.", "Line No.");
           DiscountEntry.SetRange(DiscountEntry."Store No.", TransactionHeader."Store No.");
           DiscountEntry.SetRange(DiscountEntry."POS Terminal No.", TransactionHeader."POS Terminal No.");
           DiscountEntry.SetRange(DiscountEntry."Transaction No.", TransactionHeader."Transaction No.");
           DiscountEntry.SetFilter(DiscountEntry."Offer No.", '<>%1', '');
           if DiscountEntry.find('-') then begin
               repeat
                   SellOutValuesEntries.Reset();
                   SellOutValuesEntries.SetCurrentKey("Store No.", "POS Terminal No.", "Transaction No.", "Line No.", "Offer No.", "Offer Type");
                   SellOutValuesEntries.SetRange("Store No.", DiscountEntry."Store No.");
                   SellOutValuesEntries.SetRange("POS Terminal No.", DiscountEntry."POS Terminal No.");
                   SellOutValuesEntries.SetRange("Transaction No.", DiscountEntry."Transaction No.");
                   SellOutValuesEntries.SetRange("Line No.", DiscountEntry."Line No.");
                   SellOutValuesEntries.SetRange("Offer No.", DiscountEntry."Offer No.");
                   SellOutValuesEntries.SetRange("Offer Type", DiscountEntry."Offer Type");
                   IF NOT SellOutValuesEntries.FindFirst() THEN BEGIN
                       case DiscountEntry."Offer Type" Of
                           DiscountEntry."Offer Type"::"Disc. Offer":
                               begin
                                   PerDiscountLine.Reset();
                                   PerDiscountLine.SetRange(PerDiscountLine."Offer No.", DiscountEntry."Offer No.");
                                   PerDiscountLine.SetFilter(PerDiscountLine."FSN Sell Out Type", '<>%1', PerDiscountLine."FSN Sell Out Type"::Nothing);
                                   if PerDiscountLine.FindFirst() then
                                       ValidateSellOut(DiscountEntry."Offer Type", PerDiscountLine."Offer No.", DiscountEntry."Line No.", TransactionHeader."Sale Is Return Sale", DiscountEntry."Store No.", DiscountEntry."POS Terminal No.", DiscountEntry."Transaction No.");
                               end;
                           DiscountEntry."Offer Type"::"Mix&Match":
                               begin
                                   PerDiscount.Reset();
                                   PerDiscount.setrange(PerDiscount."No.", DiscountEntry."Offer No.");
                                   PerDiscount.SetFilter(PerDiscount."FSN Sell Out Type", '<>%1', PerDiscount."FSN Sell Out Type"::Nothing);
                                   IF PerDiscount.FindFirst() THEN
                                       ValidateSellOut(DiscountEntry."Offer Type", PerDiscount."No.", DiscountEntry."Line No.", TransactionHeader."Sale Is Return Sale", DiscountEntry."Store No.", DiscountEntry."POS Terminal No.", DiscountEntry."Transaction No.");
                               end;
                           DiscountEntry."Offer Type"::Coupon:
                               begin
                                   CouponHeader.Reset();
                                   CouponHeader.SetRange(CouponHeader.Code, DiscountEntry."Offer No.");
                                   CouponHeader.SetFilter(CouponHeader."FSN Sell Out Type", '<>%1', CouponHeader."FSN Sell Out Type"::Nothing);
                                   if CouponHeader.FindFirst() then
                                       ValidateSellOut(DiscountEntry."Offer Type", CouponHeader.Code, DiscountEntry."Line No.", TransactionHeader."Sale Is Return Sale", DiscountEntry."Store No.", DiscountEntry."POS Terminal No.", DiscountEntry."Transaction No.");
                               end;

                       end;
                   END;
               until DiscountEntry.NEXT = 0;
           end;
       end;

       procedure ValidateSellOut(OfferType: Enum "LSC Trans. Disc. Ent Offer Typ"; OfferCode: Code[20]; LineNo: Integer; SaleIsReturnSale: Boolean; VStore: Code[10]; VTerminal: Code[10]; VTransNo: Integer)
       var
           TransSalesEntry: Record "LSC Trans. Sales Entry";
           PerDiscountLine: Record "LSC Periodic Discount Line";
           ValidatePerDiscount: Record "LSC Periodic Discount";
           SpecialGroupLink: record "LSC Item/Special Group Link";
           CouponHeader: Record "LSC Coupon Header";
           CouponLine: Record "LSC Coupon Line";
           ValidateItem: Record Item;
           FSNSellOutType: Integer;
           ValueExist: Boolean;
       begin
           TransSalesEntry.Reset();
           TransSalesEntry.SetCurrentKey("Store No.", "POS Terminal No.", "Transaction No.", "Line No.");
           TransSalesEntry.SetRange("Store No.", VStore);
           TransSalesEntry.SetRange("POS Terminal No.", VTerminal);
           TransSalesEntry.SetRange(TransSalesEntry."Transaction No.", VTransNo);
           TransSalesEntry.SetRange(TransSalesEntry."Line No.", LineNo);
           if TransSalesEntry.FindFirst() then begin
               if TransSalesEntry."Periodic Disc. Group" <> '' then begin
                   if OfferType = OfferType::"Disc. Offer" then begin
                       PerDiscountLine.Reset();
                       PerDiscountLine.SetRange(PerDiscountLine."Offer No.", TransSalesEntry."Periodic Disc. Group");
                       if PerDiscountLine.Find('-') then begin
                           repeat
                               IF (PerDiscountLine."FSN Sell Out Type" <> PerDiscountLine."FSN Sell Out Type"::Nothing) THEN begin
                                   ValueExist := false;
                                   case PerDiscountLine.Type of
                                       PerDiscountLine.Type::Item:
                                           begin
                                               if PerDiscountLine."No." = TransSalesEntry."Item No." then
                                                   ValueExist := true;
                                           end;
                                       PerDiscountLine.Type::"Special Group":
                                           begin
                                               SpecialGroupLink.Reset();
                                               SpecialGroupLink.SetCurrentKey("Item No.", "Special Group Code");
                                               SpecialGroupLink.SetRange("Item No.", TransSalesEntry."Item No.");
                                               SpecialGroupLink.SetRange("Special Group Code", PerDiscountLine."No.");
                                               if SpecialGroupLink.FindFirst() then
                                                   ValueExist := true;
                                           end;
                                       PerDiscountLine.Type::"Item Category", PerDiscountLine.Type::"Product Group":
                                           begin
                                               ValidateItem.reset;
                                               if ValidateItem.Get(TransSalesEntry."Item No.") then begin
                                                   if PerDiscountLine."No." in [ValidateItem."Item Category Code", ValidateItem."LSC Retail Product Code"] then
                                                       ValueExist := true;
                                               end;
                                           end;
                                   end;

                                   if ValueExist then begin
                                       InsertSellOut(TransSalesEntry, OfferType, PerDiscountLine."FSN Sell Out Type", PerDiscountLine."Offer No.", PerDiscountLine."FSN Value Sell Out", SaleIsReturnSale);
                                       exit;
                                   end;
                               end;
                           until PerDiscountLine.Next = 0;
                       end;
                   end;

                   if OfferType = OfferType::"Mix&Match" then begin
                       ValidatePerDiscount.Reset();
                       ValidatePerDiscount.setrange(ValidatePerDiscount."No.", TransSalesEntry."Periodic Disc. Group");
                       IF ValidatePerDiscount.FindFirst() THEN begin
                           InsertSellOut(TransSalesEntry, OfferType, ValidatePerDiscount."FSN Sell Out Type", ValidatePerDiscount."No.", ValidatePerDiscount."FSN Value Sell Out", SaleIsReturnSale);
                           exit;
                       end;
                   end;
               end else begin
                   if OfferType = OfferType::Coupon then begin
                       CouponHeader.Reset();
                       CouponHeader.SetRange(CouponHeader.Code, OfferCode);
                       CouponHeader.SetFilter(CouponHeader."FSN Sell Out Type", '<>%1', CouponHeader."FSN Sell Out Type"::Nothing);
                       if CouponHeader.FindFirst() then begin
                           CouponLine.Reset();
                           CouponLine.SetRange(CouponLine."Coupon Code", CouponHeader.Code);
                           if CouponLine.Find('-') then begin
                               repeat
                                   ValueExist := false;
                                   case CouponLine.Type of
                                       CouponLine.Type::Item:
                                           begin
                                               if CouponLine."No." = TransSalesEntry."Item No." then
                                                   ValueExist := true;
                                           end;
                                       CouponLine.Type::"Special Group":
                                           begin
                                               SpecialGroupLink.Reset();
                                               SpecialGroupLink.SetCurrentKey("Item No.", "Special Group Code");
                                               SpecialGroupLink.SetRange("Item No.", TransSalesEntry."Item No.");
                                               SpecialGroupLink.SetRange("Special Group Code", CouponLine."No.");
                                               if SpecialGroupLink.FindFirst() then
                                                   ValueExist := true;
                                           end;
                                       PerDiscountLine.Type::"Item Category", PerDiscountLine.Type::"Product Group":
                                           begin
                                               ValidateItem.reset;
                                               if ValidateItem.Get(TransSalesEntry."Item No.") then begin
                                                   if PerDiscountLine."No." in [ValidateItem."Item Category Code", ValidateItem."LSC Retail Product Code"] then
                                                       ValueExist := true;
                                               end;
                                           end;
                                   end;

                                   if ValueExist then begin
                                       InsertSellOut(TransSalesEntry, OfferType, CouponHeader."FSN Sell Out Type", CouponHeader.Code, CouponHeader."FSN Value Sell Out", SaleIsReturnSale);
                                       exit;
                                   end;
                               until CouponLine.Next = 0;
                           end;
                       end;
                   end;
               end;
           end;
       end;

       procedure InsertSellOut(TransSalEntry: Record "LSC Trans. Sales Entry"; OfferTypeIn: Enum "LSC Trans. Disc. Ent Offer Typ"; ISellOutType: Enum "FSN Sell Out Value Type"; OfferNo: Code[20]; ValueSellOut: Decimal; InSaleIsReturnSale: Boolean)
       var
           SellOutValuesEntries: Record "FSN Sell Out Value Entry";
       begin
           SellOutValuesEntries.INIT();
           SellOutValuesEntries."Line No." := TransSalEntry."Line No.";
           SellOutValuesEntries."Store No." := TransSalEntry."Store No.";
           SellOutValuesEntries."POS Terminal No." := TransSalEntry."POS Terminal No.";
           SellOutValuesEntries."Transaction No." := TransSalEntry."Transaction No.";
           SellOutValuesEntries."Item No." := TransSalEntry."Item No.";
           SellOutValuesEntries.Date := TransSalEntry.Date;
           SellOutValuesEntries."Receipt No." := TransSalEntry."Receipt No.";
           SellOutValuesEntries."Offer No." := OfferNo;
           SellOutValuesEntries."Offer Type" := OfferTypeIn;
           SellOutValuesEntries."Sell Out Type" := ISellOutType;
           SellOutValuesEntries."Value Sell Out" := ValueSellOut;
           if not InSaleIsReturnSale then
               SellOutValuesEntries."Sell Out Amount" := (TransSalEntry."Discount Amount" * ValueSellOut) / 100
           else
               SellOutValuesEntries."Sell Out Amount" := -((TransSalEntry."Discount Amount" * -1) * ValueSellOut) / 100;
           SellOutValuesEntries.INSERT(true);
       end;

       procedure ProcesSellOut(vPosTerminal: Code[10]; TransNoIn: Integer; TransNoFin: Integer)
       var
           TransactionHeader: Record "LSC Transaction Header";
           PerDiscountLine: Record "LSC Periodic Discount Line";
           PerDiscount: Record "LSC Periodic Discount";
           CouponHeader: Record "LSC Coupon Header";
           SellOutValuesEntriesProc: Record "FSN Sell Out Value Entry";
           SellDiscountEntry: Record "LSC Trans. Discount Entry";
       begin
           TransactionHeader.Reset();
           TransactionHeader.SetRange(TransactionHeader."POS Terminal No.", vPosTerminal);
           TransactionHeader.Setfilter(TransactionHeader."Transaction No.", '%1..%2', TransNoIn, TransNoFin);
           if TransactionHeader.find('-') then begin
               if not TransactionHeader."Sale Is Return Sale" then begin
                   repeat
                       SellDiscountEntry.Reset();
                       SellDiscountEntry.SetCurrentKey("Store No.", "POS Terminal No.", "Transaction No.");
                       SellDiscountEntry.SetRange(SellDiscountEntry."Store No.", TransactionHeader."Store No.");
                       SellDiscountEntry.SetRange(SellDiscountEntry."POS Terminal No.", TransactionHeader."POS Terminal No.");
                       SellDiscountEntry.SetRange(SellDiscountEntry."Transaction No.", TransactionHeader."Transaction No.");
                       SellDiscountEntry.SetFilter(SellDiscountEntry."Offer No.", '<>%1', '');
                       if SellDiscountEntry.find('-') then begin
                           repeat
                               SellOutValuesEntriesProc.Reset();
                               SellOutValuesEntriesProc.SetCurrentKey("Store No.", "POS Terminal No.", "Transaction No.", "Line No.", "Offer No.", "Offer Type");
                               SellOutValuesEntriesProc.SetRange("Store No.", SellDiscountEntry."Store No.");
                               SellOutValuesEntriesProc.SetRange("POS Terminal No.", SellDiscountEntry."POS Terminal No.");
                               SellOutValuesEntriesProc.SetRange("Transaction No.", SellDiscountEntry."Transaction No.");
                               SellOutValuesEntriesProc.SetRange("Line No.", SellDiscountEntry."Line No.");
                               SellOutValuesEntriesProc.SetRange("Offer No.", SellDiscountEntry."Offer No.");
                               SellOutValuesEntriesProc.SetRange("Offer Type", SellDiscountEntry."Offer Type");
                               IF NOT SellOutValuesEntriesProc.FindFirst() THEN BEGIN
                                   case SellOutValuesEntriesProc."Offer Type" of
                                       SellOutValuesEntriesProc."Offer Type"::"Disc. Offer":
                                           begin
                                               PerDiscountLine.Reset();
                                               PerDiscountLine.SetRange(PerDiscountLine."Offer No.", SellDiscountEntry."Offer No.");
                                               PerDiscountLine.SetFilter(PerDiscountLine."FSN Sell Out Type", '<>%1', PerDiscountLine."FSN Sell Out Type"::Nothing);
                                               if PerDiscountLine.FindFirst() then
                                                   ValidateSellOut(SellDiscountEntry."Offer Type", PerDiscountLine."Offer No.", SellDiscountEntry."Line No.", TransactionHeader."Sale Is Return Sale", TransactionHeader."Store No.", TransactionHeader."POS Terminal No.", TransactionHeader."Transaction No.");
                                           end;
                                       SellDiscountEntry."Offer Type"::"Mix&Match":
                                           begin
                                               PerDiscount.Reset();
                                               PerDiscount.setrange(PerDiscount."No.", SellDiscountEntry."Offer No.");
                                               PerDiscount.SetFilter(PerDiscount."FSN Sell Out Type", '<>%1', PerDiscount."FSN Sell Out Type"::Nothing);
                                               IF PerDiscount.FindFirst() THEN
                                                   ValidateSellOut(SellDiscountEntry."Offer Type", PerDiscount."No.", SellDiscountEntry."Line No.", TransactionHeader."Sale Is Return Sale", TransactionHeader."Store No.", TransactionHeader."POS Terminal No.", TransactionHeader."Transaction No.");
                                           end;
                                       SellDiscountEntry."Offer Type"::Coupon:
                                           begin
                                               CouponHeader.Reset();
                                               CouponHeader.SetRange(CouponHeader.Code, SellDiscountEntry."Offer No.");
                                               CouponHeader.SetFilter(CouponHeader."FSN Sell Out Type", '<>%1', CouponHeader."FSN Sell Out Type"::Nothing);
                                               if CouponHeader.FindFirst() then
                                                   ValidateSellOut(SellDiscountEntry."Offer Type", CouponHeader.Code, SellDiscountEntry."Line No.", TransactionHeader."Sale Is Return Sale", TransactionHeader."Store No.", TransactionHeader."POS Terminal No.", TransactionHeader."Transaction No.");
                                           end;

                                   end;
                               END;
                           until SellDiscountEntry.NEXT = 0;
                       end;
                   until TransactionHeader.Next = 0;
               end;
           end;
       end;*/

}