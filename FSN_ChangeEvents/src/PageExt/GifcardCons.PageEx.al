pageextension 50039 MyExtension extends "FSN Giftcard Load"
{
    layout
    {
        // Add changes to page layout here
        modify(Option_5_1)
        {
            Visible = false;
        }

        addafter(Decimal_1)
        {
            field(Option_5_2; Option_5_2)
            {
                Caption = 'Entry Type';
                Editable = true;
                OptionCaption = 'Empresa,Fasani,Personal';
                trigger OnValidate()
                var
                    myInt: Integer;
                begin
                    Option_5_1 := Option_5_2;
                end;
            }
        }
    }

    actions
    {
        modify(Create)
        {
            Promoted = false;
            Visible = false;
        }
        // Add changes to page actions here
        addafter(Create)
        {
            action(Crear)
            {
                Caption = 'crear ';
                Image = "Action";
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                begin

                    GlobalTemp.RESET;
                    GlobalTemp.SETRANGE(GlobalTemp.Code10_1, 'GIFTCARD');
                    IF GlobalTemp.FIND('-') THEN
                        REPEAT
                            DataEntry.RESET;
                            DataEntry.SETRANGE(DataEntry."Entry Code", GlobalTemp.Code20_1);
                            IF DataEntry.FIND('-') THEN BEGIN
                                IF GlobalTemp.Bool_1 THEN BEGIN//Is New
                                    GlobalTemp."Message Process" := IText003;
                                    GlobalTemp.MODIFY(TRUE);
                                END ELSE BEGIN
                                    IF (GlobalTemp.Decimal_1 = 0) THEN BEGIN
                                        GlobalTemp."Message Process" := IText002;
                                        GlobalTemp.MODIFY(TRUE);
                                    END ELSE BEGIN
                                        DataEntry.Amount := DataEntry.Amount + GlobalTemp.Decimal_1;
                                        DataEntry.Applied := DataEntry.Amount = 0;
                                        DataEntry."Expiring Date" := GlobalTemp.Date_2;
                                        DataEntry.MODIFY(TRUE);

                                        //Store No.,POS Terminal No.,Transaction No.,Line No.,Receipt Number
                                        Voucher.INIT;
                                        Voucher."Store No." := 'HO';
                                        Voucher."POS Terminal No." := 'HO';
                                        Voucher."Transaction No." := 1;

                                        TransactionHdr.RESET;
                                        TransactionHdr.SETCURRENTKEY(TransactionHdr."Receipt No.");
                                        TransactionHdr.SETRANGE(TransactionHdr."Receipt No.", GlobalTemp.Code20_2);
                                        TransactionHdr.SETRANGE(TransactionHdr."Entry Status", 0);
                                        IF TransactionHdr.FIND('-') THEN
                                            Voucher."Transaction No." := TransactionHdr."Transaction No.";
                                        Voucher."Voucher No." := GlobalTemp.Code20_1;
                                        Voucher."Receipt Number" := GlobalTemp.Code20_2;
                                        IF Voucher."Receipt Number" = '' THEN
                                            Voucher."Receipt Number" := 'HOS';

                                        Voucher."Line No." := 10;
                                        NextVoucherLine.RESET;
                                        NextVoucherLine.SETCURRENTKEY(NextVoucherLine."Store No.", NextVoucherLine."POS Terminal No."
                                            , NextVoucherLine."Transaction No.", NextVoucherLine."Line No.", NextVoucherLine."Receipt Number");
                                        NextVoucherLine.SETRANGE(NextVoucherLine."Store No.", Voucher."Store No.");
                                        NextVoucherLine.SETRANGE(NextVoucherLine."POS Terminal No.", Voucher."POS Terminal No.");
                                        NextVoucherLine.SETRANGE(NextVoucherLine."Transaction No.", Voucher."Transaction No.");
                                        NextVoucherLine.SETRANGE(NextVoucherLine."Receipt Number", Voucher."Receipt Number");
                                        IF NextVoucherLine.FIND('+') THEN
                                            Voucher."Line No." := NextVoucherLine."Line No." + 10;

                                        Voucher.Amount := GlobalTemp.Decimal_1;
                                        Voucher."Entry Type" := 0;
                                        Voucher.Voided := FALSE;
                                        Voucher.Date := TODAY;
                                        Voucher.Time := TIME;
                                        CASE GlobalTemp.Option_5_1 OF
                                            0:
                                                Voucher."Voucher Type" := 'GIFTCARDNO';
                                            1:
                                                Voucher."Voucher Type" := 'GIFTCARDFS';
                                            ELSE
                                                Voucher."Voucher Type" := 'GIFTCARDDE';
                                        END;
                                        Voucher.INSERT;
                                        GlobalTemp.DELETE;
                                    END;
                                END;
                            END ELSE BEGIN
                                IF NOT GlobalTemp.Bool_1 THEN BEGIN
                                    GlobalTemp."Message Process" := IText001;
                                    GlobalTemp.MODIFY(TRUE);
                                END ELSE BEGIN
                                    DataEntry.INIT;
                                    IF GlobalTemp.Decimal_1 = 0 THEN BEGIN
                                        GlobalTemp."Message Process" := IText002;
                                        GlobalTemp.MODIFY(TRUE);
                                    END ELSE BEGIN
                                        IF GlobalTemp.Date_2 = 0D THEN BEGIN
                                            GlobalTemp."Message Process" := IText004;
                                            GlobalTemp.MODIFY(TRUE);
                                        END ELSE BEGIN
                                            CASE GlobalTemp.Option_5_1 OF
                                                0:
                                                    DataEntry."Entry Type" := 'GIFTCARDNO';
                                                1:
                                                    DataEntry."Entry Type" := 'GIFTCARDFS';
                                                ELSE
                                                    DataEntry."Entry Type" := 'GIFTCARDDE';
                                            END;
                                            DataEntry."Entry Code" := GlobalTemp.Code20_1;
                                            DataEntry.Amount := GlobalTemp.Decimal_1;
                                            DataEntry."Created by Receipt No." := GlobalTemp.Code20_2;
                                            DataEntry."Created by Line No." := 1;
                                            IF DataEntry."Created by Receipt No." = '' THEN
                                                DataEntry."Created by Receipt No." := 'HOS';
                                            DataEntry."Date Created" := TODAY;
                                            DataEntry."Expiring Date" := GlobalTemp.Date_2;
                                            DataEntry."Created in Store No." := 'HO';
                                            DataEntry.Applied := FALSE;
                                            DataEntry."Applied by Receipt No." := DataEntry."Created by Receipt No.";
                                            DataEntry."Applied by Line No." := DataEntry."Created by Line No.";
                                            DataEntry.INSERT;

                                            Voucher.INIT;
                                            Voucher."Store No." := 'HO';
                                            Voucher."POS Terminal No." := 'HO';
                                            Voucher."Transaction No." := 1;
                                            CASE GlobalTemp.Option_5_1 OF
                                                0:
                                                    Voucher."Voucher Type" := 'GIFTCARDNO';
                                                1:
                                                    Voucher."Voucher Type" := 'GIFTCARDFS';
                                                ELSE
                                                    Voucher."Voucher Type" := 'GIFTCARDDE';
                                            END;

                                            TransactionHdr.RESET;
                                            TransactionHdr.SETCURRENTKEY(TransactionHdr."Receipt No.");
                                            TransactionHdr.SETRANGE(TransactionHdr."Receipt No.", GlobalTemp.Code20_2);
                                            TransactionHdr.SETRANGE(TransactionHdr."Entry Status", 0);
                                            IF TransactionHdr.FIND('-') THEN
                                                Voucher."Transaction No." := TransactionHdr."Transaction No.";
                                            Voucher."Voucher No." := GlobalTemp.Code20_1;
                                            Voucher."Receipt Number" := GlobalTemp.Code20_2;
                                            IF Voucher."Receipt Number" = '' THEN
                                                Voucher."Receipt Number" := 'HOS';

                                            Voucher."Line No." := 10;
                                            NextVoucherLine.RESET;
                                            NextVoucherLine.SETCURRENTKEY(NextVoucherLine."Store No.", NextVoucherLine."POS Terminal No."
                                                , NextVoucherLine."Transaction No.", NextVoucherLine."Line No.", NextVoucherLine."Receipt Number");
                                            NextVoucherLine.SETRANGE(NextVoucherLine."Store No.", Voucher."Store No.");
                                            NextVoucherLine.SETRANGE(NextVoucherLine."POS Terminal No.", Voucher."POS Terminal No.");
                                            NextVoucherLine.SETRANGE(NextVoucherLine."Transaction No.", Voucher."Transaction No.");
                                            NextVoucherLine.SETRANGE(NextVoucherLine."Receipt Number", Voucher."Receipt Number");
                                            IF NextVoucherLine.FIND('+') THEN
                                                Voucher."Line No." := NextVoucherLine."Line No." + 10;

                                            Voucher.Amount := GlobalTemp.Decimal_1;
                                            Voucher."Entry Type" := 0;
                                            Voucher.Voided := FALSE;
                                            Voucher.Date := TODAY;
                                            Voucher.Time := TIME;
                                            Voucher.INSERT;
                                            GlobalTemp.DELETE;
                                        END;
                                    END;
                                END;
                            END;
                        UNTIL GlobalTemp.NEXT = 0;

                    MESSAGE(IText005);
                end;
            }
        }
    }


    var
        Voucher: Record "LSC Voucher Entries";
        GlobalTemp: Record "FSN Global Table Temporary";
        DataEntry: Record "LSC POS Data Entry";
        CodGift: Code[25];
        CodGiftText: Text;
        IText001: Label 'Debe seleccionar check  para GiftCard Nuevas';
        IText002: Label 'Monto no puede ser Cero';
        IText003: Label 'GiftCard ya existe, no puede tener check en Nuevo';
        ii: Integer;
        IText004: Label 'Debe agregar  Fecha Caducidad';
        IText005: Label 'Proceso finalizado!!';
        NextVoucherLine: Record "LSC Voucher Entries";
        TransactionHdr: Record "LSC Transaction Header";
}