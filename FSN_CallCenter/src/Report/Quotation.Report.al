report 50008 "FSN Quotation"
{
    DefaultLayout = RDLC;
    RDLCLayout = './src/Report/Layout/Quotation.rdl';

    dataset
    {
        dataitem(DataItem1000000000; "LSC POS Transaction")
        {
            column(ReceiptNo_POSTransaction; DataItem1000000000."Receipt No.")
            {
            }
            column(StoreNo_POSTransaction; DataItem1000000000."Store No.")
            {
            }
            column(POSTerminalNo_POSTransaction; DataItem1000000000."POS Terminal No.")
            {
            }
            column(StaffID_POSTransaction; DataItem1000000000."Staff ID")
            {
            }
            column(TransDate_POSTransaction; DataItem1000000000."Trans. Date")
            {
            }
            column(CustomerNo_POSTransaction; DataItem1000000000."Customer No.")
            {
            }
            column(NetAmount_POSTransaction; DataItem1000000000."Net Amount")
            {
            }
            column(GrossAmount_POSTransaction; DataItem1000000000."Gross Amount")
            {
            }
            column(RazonSocial_POSTransaction; DataItem1000000000."FSN NCF")
            {
            }
            column(NoSerieNCF_POSTransaction; DataItem1000000000."FSN No. Serie NCF")
            {
            }
            column(DUI_POSTransaction; DataItem1000000000."FSN DUI")
            {
            }
            column(NIT_POSTransaction; DataItem1000000000."FSN NIT")
            {
            }
            dataitem(DataItem1000000013; "LSC POS Trans. Line")
            {
                DataItemLink = "Receipt No." = FIELD("Receipt No.");
                DataItemTableView = WHERE("Entry Status" = CONST(" "),
                                          "Entry Type" = CONST(Item));
                column(LineNo_POSTransLine; DataItem1000000013."Line No.")
                {
                }
                column(BarcodeNo_POSTransLine; DataItem1000000013."Barcode No.")
                {
                }
                column(Description_POSTransLine; DataItem1000000013.Description)
                {
                }
                column(UnitofMeasure_POSTransLine; DataItem1000000013."Unit of Measure")
                {
                }
                column(Quantity_POSTransLine; DataItem1000000013.Quantity)
                {
                }
                column(Discount_POSTransLine; DataItem1000000013."Discount %")
                {
                }
                column(Price_POSTransLine; DataItem1000000013.Price)
                {
                }
                column(DiscountPerc_POSTransLine; DataItem1000000013."Discount %")
                {
                }
                column(Amount_POSTransLine; DataItem1000000013.Amount)
                {
                }
                column(CashLine; CashLine)
                {
                }
                column(CardLine; CardLine)
                {
                }
                column(CashTotal; CashTotal)
                {
                }
                column(CardTotal; CardTotal)
                {
                }
                column(CashLineAmount; CashLineAmount)
                {
                }
                column(CardLineAmount; CardLineAmount)
                {
                }
                column(isCash; isCash)
                {
                }
                column(isCard; isCard)
                {
                }
                column(DiscountAmount_POSTransLine; DataItem1000000013."Discount Amount")
                {
                }
                column(vTipoPago; vTenderType)
                {
                }
                column(vPrecio; vPrecio)
                {
                }
                column(vPorcDescuento; vPorcDescuento)
                {
                }
                column(vDescuento; vDescuento)
                {
                }
                column(vTotal; vTotal)
                {
                }
                column(MedioPago; MedioPago)
                {
                }
                column(NombreStaff; vNombreStaff)
                {
                }
                column(NombreCliente; NombreCliente)
                {
                }

                trigger OnAfterGetRecord()
                begin

                    CASE vTenderType OF
                        vTenderType::Efectivo:
                            BEGIN
                                MedioPago := 'Efectivo';
                                vPorcDescuento := FORMAT(GetTenderTypeDiscount('1', DataItem1000000013)) + '%';
                                vTotal := GetTenderTypeDiscountAmount('1', DataItem1000000013);
                            END;
                        vTenderType::Tarjeta:
                            BEGIN
                                MedioPago := 'Tarjeta de credito';
                                vPorcDescuento := FORMAT(GetTenderTypeDiscount('20', DataItem1000000013)) + '%';
                                vTotal := GetTenderTypeDiscountAmount('20', DataItem1000000013);
                            END;
                        vTenderType::Credito:
                            BEGIN
                                MedioPago := 'Al credito';
                                vPorcDescuento := FORMAT(GetTenderTypeDiscount('4', DataItem1000000013)) + '%';
                                vTotal := GetTenderTypeDiscountAmount('4', DataItem1000000013);
                            END;
                        vTenderType::Cheque:
                            BEGIN
                                MedioPago := 'Cheque';
                                vPorcDescuento := FORMAT(GetTenderTypeDiscount('2', DataItem1000000013)) + '%';
                                vTotal := GetTenderTypeDiscountAmount('2', DataItem1000000013);
                            END;
                    END;

                    vPrecio := DataItem1000000013.Price;

                    //CSPNT150118
                    IF "Discount %" = 0 THEN BEGIN
                        IF vTotal > 0 THEN
                            vDescuento := DataItem1000000013.Amount - vTotal
                        ELSE BEGIN
                            vDescuento := 0.0;
                            vTotal := DataItem1000000013.Amount;
                        END;
                    END
                    ELSE BEGIN
                        vPorcDescuento := FORMAT(ROUND("Discount %", 0.01)) + '%';
                        vDescuento := "Discount Amount";
                        vTotal := Amount;
                    END;
                end;
            }


            trigger OnAfterGetRecord()
            begin

                IF rStaff.GET(DataItem1000000000."Staff ID") THEN
                    vNombreStaff := rStaff."First Name" + ' ' + rStaff."Last Name";

                if Contact.Get(DataItem1000000000."Sell-to Contact No.") then
                    NombreCliente := Contact.Name;
            end;
        }
    }

    requestpage
    {

        layout
        {
            area(content)
            {
                field("Tipo Pago"; vTenderType)
                {
                }
            }
        }

        actions
        {
        }
    }

    labels
    {
    }

    var
        CashLine: Text;
        CashLineAmount: Decimal;
        CardLine: Text;
        CardLineAmount: Decimal;
        CashTotal: Text;
        CardTotal: Text;
        PosTransaction: Record "LSC POS Transaction";
        PeriodicDisc: Record "LSC Periodic Discount";
        PeriodicDisc1: Record "LSC Periodic Discount";
        PeriodicDiscLine: Record "LSC Periodic Discount Line";
        PeriodicDiscLine1: Record "LSC Periodic Discount Line";
        SpecialGroup: Record "LSC Item/Special Group Link";
        isVIP: Boolean;
        Customer: Code[20];
        Cust: Record "Customer";
        isCash: Boolean;
        isCard: Boolean;
        vTenderType: Option Efectivo,Tarjeta,Credito,Cheque;
        vPrecio: Decimal;
        vPorcDescuento: Text;
        vDescuento: Decimal;
        vTotal: Decimal;
        MedioPago: Text;
        rStaff: Record "LSC Staff";
        vNombreStaff: Text;
        Contact: Record Contact;
        NombreCliente: Text;


    procedure SetTenderType(TenderT: Option)
    begin

        vTenderType := TenderT;
    end;


    procedure GetTenderTypeDiscount(TenderType: Code[10]; PosTransLine: Record "LSC POS Trans. Line"): Decimal
    begin

        PosTransaction.GET(PosTransLine."Receipt No.");

        IF PosTransaction."Member Card No." = '' THEN
            isVIP := FALSE
        ELSE
            isVIP := TRUE;

        //CSMQ090216*********************
        Customer := '';
        IF PosTransaction."Customer No." <> '' THEN
            IF Cust.GET(PosTransaction."Customer No.") THEN
                Customer := Cust."No.";
        //*******************************

        PeriodicDisc.RESET;
        PeriodicDisc.SETFILTER("Offer Type", '<>6');
        PeriodicDisc.SETRANGE(Status, PeriodicDisc.Status::Enabled);
        //CSMQ160216*********************************************************************
        IF PosTransaction."Customer No." <> '' THEN
            PeriodicDisc.SETRANGE("Customer Disc. Group", Cust."Customer Disc. Group")
        ELSE
            PeriodicDisc.SETRANGE("Customer Disc. Group", '');
        //*******************************************************************************

        IF PeriodicDisc.FIND('-') THEN
            REPEAT
                PeriodicDiscLine.RESET;
                PeriodicDiscLine.SETRANGE("Offer No.", PeriodicDisc."No.");
                PeriodicDiscLine.SETRANGE("No.", PosTransLine.Number);
            UNTIL (PeriodicDisc.NEXT = 0) OR (PeriodicDiscLine.FINDFIRST);

        //IF NOT PeriodicDisc.FINDFIRST OR NOT PeriodicDiscLine.FINDFIRST THEN BEGIN
        PeriodicDisc1.RESET;
        PeriodicDisc1.SETRANGE("Offer Type", PeriodicDisc."Offer Type"::"Tender Type");
        PeriodicDisc1.SETRANGE("Tender Type Code", TenderType);
        IF isVIP THEN
            PeriodicDisc1.SETRANGE("Customer Disc. Group", 'VIP')
        ELSE
            //CSMQ090216********************************************************************
            //Nuevas validaciones por grupo de descuento de cliente
            //PeriodicDisc1.SETFILTER("Member Value", '<>VIP');
            IF Customer = '' THEN
                PeriodicDisc1.SETRANGE("Customer Disc. Group", '')
            ELSE
                PeriodicDisc1.SETRANGE("Customer Disc. Group", Cust."Customer Disc. Group");
        //*******************************************************************************
        PeriodicDisc1.SETRANGE(Status, PeriodicDisc1.Status::Enabled);
        IF PeriodicDisc1.FIND('-') THEN
            REPEAT
                PeriodicDiscLine1.RESET;
                PeriodicDiscLine1.SETRANGE("Offer No.", PeriodicDisc1."No.");
                PeriodicDiscLine1.SETRANGE("No.", PosTransLine.Number);
                IF PeriodicDiscLine1.FINDFIRST THEN
                    EXIT(PeriodicDisc1."Tender Offer %");

                //CSMQ100616-
                //Validacion extra para Grupos Especiales
                PeriodicDiscLine1.SETRANGE("No.");
                PeriodicDiscLine1.SETRANGE(Type, PeriodicDiscLine1.Type::"Special Group");
                IF PeriodicDiscLine1.FIND('-') THEN
                    REPEAT
                        IF SpecialGroup.GET(PosTransLine.Number, PeriodicDiscLine1."No.") THEN
                            EXIT(PeriodicDisc1."Tender Offer %");
                    UNTIL PeriodicDiscLine1.NEXT = 0;
            //CSMQ100616+
            UNTIL PeriodicDisc1.NEXT = 0;
        //END;
        EXIT(0);
    end;


    procedure GetTenderTypeDiscountAmount(TenderType: Code[10]; PosTransLine: record "LSC POS Trans. Line"): Decimal
    begin

        PosTransaction.GET(PosTransLine."Receipt No.");

        IF PosTransaction."Member Card No." = '' THEN
            isVIP := FALSE
        ELSE
            isVIP := TRUE;

        //CSMQ090216*********************
        Customer := '';
        IF PosTransaction."Customer No." <> '' THEN
            IF Cust.GET(PosTransaction."Customer No.") THEN
                Customer := Cust."No.";
        //*******************************

        PeriodicDisc.RESET;
        PeriodicDisc.SETFILTER("Offer Type", '<>6');
        PeriodicDisc.SETRANGE(Status, PeriodicDisc.Status::Enabled);
        //CSMQ160216*********************************************************************
        IF PosTransaction."Customer No." <> '' THEN
            PeriodicDisc.SETRANGE("Customer Disc. Group", Cust."Customer Disc. Group")
        ELSE
            PeriodicDisc.SETRANGE("Customer Disc. Group", '');
        //*******************************************************************************

        IF PeriodicDisc.FIND('-') THEN
            REPEAT
                PeriodicDiscLine.RESET;
                PeriodicDiscLine.SETRANGE("Offer No.", PeriodicDisc."No.");
                PeriodicDiscLine.SETRANGE("No.", PosTransLine.Number);
            UNTIL (PeriodicDisc.NEXT = 0) OR (PeriodicDiscLine.FINDFIRST);

        //IF NOT PeriodicDisc.FINDFIRST OR NOT PeriodicDiscLine.FINDFIRST THEN BEGIN
        PeriodicDisc1.RESET;
        PeriodicDisc1.SETRANGE("Offer Type", PeriodicDisc."Offer Type"::"Tender Type");
        PeriodicDisc1.SETRANGE("Tender Type Code", TenderType);
        IF isVIP THEN
            PeriodicDisc1.SETRANGE("Customer Disc. Group", 'VIP')
        ELSE
            //CSMQ090216********************************************************************
            //Nuevas validaciones por grupo de descuento de cliente
            //PeriodicDisc1.SETFILTER("Member Value", '<>VIP');
            IF Customer = '' THEN
                PeriodicDisc1.SETRANGE("Customer Disc. Group", '')
            ELSE
                PeriodicDisc1.SETRANGE("Customer Disc. Group", Cust."Customer Disc. Group");
        //*******************************************************************************
        PeriodicDisc1.SETRANGE(Status, PeriodicDisc1.Status::Enabled);
        IF PeriodicDisc1.FIND('-') THEN
            REPEAT
                PeriodicDiscLine1.RESET;
                PeriodicDiscLine1.SETRANGE("Offer No.", PeriodicDisc1."No.");
                PeriodicDiscLine1.SETRANGE("No.", PosTransLine.Number);

                IF PeriodicDiscLine1.FINDFIRST THEN
                    //EXIT(FORMAT(PeriodicDisc1."Tender Offer %") + '% / ' + '$' +
                    EXIT((ROUND((PosTransLine.Amount + PosTransLine."Periodic Discount Amount") -
              ((PosTransLine.Amount + PosTransLine."Periodic Discount Amount") *
              (PeriodicDisc1."Tender Offer %" / 100)), 0.01))); //CSMQ020516 Nuevo calculo para montos con descuento

                //CSMQ100616-
                //Validacion extra para Grupos Especiales
                PeriodicDiscLine1.SETRANGE("No.");
                PeriodicDiscLine1.SETRANGE(Type, PeriodicDiscLine1.Type::"Special Group");
                IF PeriodicDiscLine1.FIND('-') THEN
                    REPEAT
                        IF SpecialGroup.GET(PosTransLine.Number, PeriodicDiscLine1."No.") THEN
                            //EXIT(FORMAT(PeriodicDisc1."Tender Offer %") + '% / ' + '$' +
                            EXIT((ROUND((PosTransLine.Amount + PosTransLine."Periodic Discount Amount") -
                  ((PosTransLine.Amount + PosTransLine."Periodic Discount Amount") *
                  (PeriodicDisc1."Tender Offer %" / 100)), 0.01))); //CSMQ020516 Nuevo calculo para montos con descuento en grupos especiales
                    UNTIL PeriodicDiscLine1.NEXT = 0;
            //CSMQ100616+
            UNTIL PeriodicDisc1.NEXT = 0;
        //END;
        EXIT(0);
    end;
}

