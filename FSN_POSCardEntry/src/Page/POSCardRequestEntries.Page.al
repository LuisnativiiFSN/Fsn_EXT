page 50007 "FSN POS Card Request Entries"
{

    Caption = 'POS Card Request Entries';
    DelayedInsert = false;
    DeleteAllowed = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    PageType = List;
    SourceTable = "FSN POS Card Request Entry";

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field(Type; IsReversTxt)
                {
                    Caption = 'Type';
                    Editable = false;
                    StyleExpr = StyleTxt;
                }
                field("Entry No."; "Entry No.")
                {
                }
                field("Date Key"; "Date Key")
                {
                }
                field("Entity Name"; "Entity Name")
                {
                }
                field("Type Request"; "Type Request")
                {
                }
                field("Cast Last Numbers"; "Cast Last Numbers")
                {
                }
                field(BIN; BIN)
                {
                }
                field(CVV; CVV)
                {
                }
                field("Bank Name"; "Bank Name")
                {
                }
                field(Date; Date)
                {
                }
                field("Store No."; "Store No.")
                {
                }
                field("Receipt No."; "Receipt No.")
                {
                }
                field("Line No."; "Line No.")
                {
                }
                field("Enter Input"; "Enter Input")
                {
                }
                field("Amount Input"; "Amount Input")
                {
                }
                field(Amount; Amount)
                {
                }
                field("Tender Type"; "Tender Type")
                {
                }
                field(User; User)
                {
                }
                field("Customer No."; "Customer No.")
                {
                }
                field("Authorization Code"; "Authorization Code")
                {
                }
                field("Response Web Ok"; "Response Web Ok")
                {
                }
                field(Command; Command)
                {
                }
                field("Send Audit No"; "Send Audit No")
                {
                }
                field("Receipt ID"; "Receipt ID")
                {
                }
                field("Entry Mode"; "Entry Mode")
                {
                }
                field("Trans Time"; "Trans Time")
                {
                }
                field("Trans Date"; "Trans Date")
                {
                }
                field("Trans Reference"; "Trans Reference")
                {
                }
                field("Trans Authorization"; "Trans Authorization")
                {
                }
                field("Trans Tipo Mssg"; "Trans Tipo Mssg")
                {
                }
                field("Void Number"; "Void Number")
                {
                }
            }
        }
    }

    actions
    {
        area(processing)
        {
            group("FSN Online")
            {
                action("Void Transaction")
                {
                    Caption = 'Void Transaction';
                    Image = CancelIndent;

                    trigger OnAction()
                    var
                        _EntryNo: Integer;
                        _Date: Date;
                        _AmountDecimal: Decimal;
                        _Remaining: Decimal;
                    begin
                        RetailSetup.GET();
                        IF "Distribution Location" <> RetailSetup."Local Store No." THEN
                            ERROR(STRSUBSTNO(Text020, RetailSetup."Local Store No.", "Distribution Location"));

                        //ERROR('Funcion no autorizada');
                        _Date := "Date Key";
                        IF _Date <> TODAY THEN
                            ERROR(Text001);

                        EVALUATE(_AmountDecimal, "Enter Input");
                        _AmountDecimal := _AmountDecimal / 100;

                        IF NOT "Response Web Ok" THEN
                            ERROR(STRSUBSTNO(Text006, Text007));
                        IF "Void Number" > 0 THEN
                            ERROR(STRSUBSTNO(Text006, Text008));

                        _Remaining := CheckReverse(Rec); //WVILLALTA 11.20-
                        IF _Remaining <> _AmountDecimal THEN
                            ERROR(STRSUBSTNO(Text018, FORMAT(_Remaining), FORMAT(_AmountDecimal))); //WVILLALTA 11.20+

                        IF NOT CONFIRM(STRSUBSTNO(Text002, "Cast Last Numbers", FORMAT(_AmountDecimal), "Trans Reference")) THEN
                            EXIT;

                        _EntryNo := 0;
                        POSCardIntegration.SetGlobalCommandManual(Command + 'A');
                        POSCardIntegration.SetGlobalDateContext(_Date);
                        IF NOT POSCardIntegration.ValidateVoidRequest(Rec, _EntryNo, _Date) THEN BEGIN
                            POSCardEntryRequest2.RESET;
                            POSCardEntryRequest2.SETCURRENTKEY("Response Web Ok", "Void Number");
                            POSCardEntryRequest2.SETRANGE(POSCardEntryRequest2."Response Web Ok", TRUE);
                            POSCardEntryRequest2.SETRANGE(POSCardEntryRequest2."Void Number", "Entry No.");
                            POSCardEntryRequest2.SETRANGE(POSCardEntryRequest2."Date Key", "Date Key");
                            IF POSCardEntryRequest2.FINDFIRST THEN
                                MESSAGE(STRSUBSTNO(Text003, FORMAT(POSCardEntryRequest2."Entry No."), POSCardEntryRequest2."Trans Authorization", POSCardEntryRequest2."Trans Reference"))
                            ELSE
                                MESSAGE(Text004);
                            EXIT;
                        END;

                        POSCardEntryRequest2.GET(_EntryNo, _Date, RetailSetup."Distribution Location");
                        IF POSCardEntryRequest2."Entity Name" = 'CREDOMATIC' THEN begin
                            Message(Text023);
                            exit;
                        end
                        ELSE
                            POSCardIntegration.SendVoidRequest(Rec, POSCardEntryRequest2);

                        COMMIT;
                        POSCardEntryRequest2.GET(_EntryNo, _Date, RetailSetup."Distribution Location");
                        IF NOT POSCardEntryRequest2."Response Web Ok" THEN
                            MESSAGE(STRSUBSTNO(Text013, ''));
                    end;
                }
                action(Information)
                {
                    Caption = 'Information';
                    Image = Info;
                    Promoted = true;
                    PromotedCategory = "Report";
                    PromotedIsBig = true;
                    trigger OnAction()
                    var

                        Texts: Text;
                        DecimalConvert: Decimal;
                        InputValue: Text[14];
                        DecimalConvert2: Decimal;
                        StringNet: DotNet String;
                        lTenderTypeSetup: Record "LSC Tender Type Setup";
                        lStaff: Record "LSC Staff";
                        TransType: Option Normal,Point,Term,Void;
                    begin
                        Texts := '';
                        Texts := FIELDCAPTION("Date Key") + ':' + FORMAT("Date Key") + '\';

                        IF Command = 'MANCONMILLA' THEN
                            Texts += STRSUBSTNO(Text009, Text010)
                        ELSE BEGIN
                            TransType := POSCardIntegration.GetIntCommand(Command);
                            Texts += STRSUBSTNO(Text009, FORMAT(TransType));
                        END;
                        IF "Enter Input" = '' THEN BEGIN
                            InputValue := '0';
                            Texts += STRSUBSTNO(Text011, '0.00');
                        END;
                        IF "Response Web Ok" THEN BEGIN
                            Texts += Text012;
                            EVALUATE(DecimalConvert, "Enter Input");
                            IF STRPOS("Enter Input", '.') = 0 THEN
                                DecimalConvert := DecimalConvert / 100;

                            IF "Void Number" > 0 THEN
                                DecimalConvert2 := DecimalConvert
                            ELSE BEGIN
                                EVALUATE(DecimalConvert2, "Amount Input");
                                IF STRPOS("Amount Input", '.') = 0 THEN
                                    DecimalConvert2 := DecimalConvert2 / 100;

                            END;
                            Texts += STRSUBSTNO(Text014, FORMAT(DecimalConvert), FORMAT(DecimalConvert2));
                            IF "Tender Type" <> '' THEN
                                IF lTenderTypeSetup.GET("Tender Type") THEN
                                    Texts += STRSUBSTNO(Text015, lTenderTypeSetup.Description);

                        END ELSE
                            IF ("Authorization Code" <> '') AND ("Authorization Code" <> '00') THEN
                                Texts += STRSUBSTNO(Text013, POSCardExternalCnn.SRFGetErrorCodeText("Authorization Code"))
                            ELSE
                                IF Command <> 'MANCONMILLA' THEN
                                    Texts += Text007;

                        IF Rec.User <> '' THEN
                            IF lStaff.GET(Rec.User) THEN
                                Texts += STRSUBSTNO(Text016, lStaff."First Name", lStaff."Last Name");
                        MESSAGE(Texts);
                    end;
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        IsReversTxt := Text022;
        StyleTxt := 'None';
        IF "Void Number" > 0 THEN BEGIN
            IsReversTxt := Text021;
            StyleTxt := 'Unfavorable';
        END;

        if Rec."Amount Input" <> '' then begin
            EVALUATE(Amount, Rec."Amount Input");
            IF STRPOS(Rec."Amount Input", '.') = 0 THEN
                Amount := Amount / 100;
        end;
    end;

    var
        IsReversTxt: Text[10];
        StyleTxt: Text[20];
        Text021: Label 'Reverse';
        Text022: Label 'Buy';
        Text001: Label 'It is possible to cancel transactions with today''s date';
        Text002: Label 'Transaction (Last Digit: %1, Amount: %2 , Ref. %3). Do you want void transaction?';
        Text003: Label 'This Transaction already void. References: Entry %1, Authorization %2, Ref. Bank %3';
        Text004: Label 'Cant be void. Error not found.';
        Text006: Label 'Transaction selected not require void. %1';
        Text007: Label 'Is not sucessfull.';
        Text008: Label 'Is Void.';
        Text009: Label 'Trans. Type "%1"\';
        Text010: Label 'point query\';
        Text011: Label 'Amount Trans. $%1\';
        Text012: Label 'Operator response sucessfull\';
        Text013: Label 'Transac. Fail : %1\';
        Text014: Label 'Amount request $%1, amount response $%2\';
        Text015: Label 'Tender Type: %1\';
        Text016: Label 'Operator %1 %2';
        Text018: Label 'Remaining is %1 different to amount original %2';
        Text019: Label 'For security cant be void voucher, the order original isnt finalized.\Steps solutions: \1)Cancel complete the order %1 (%2) \2)Try transaction';
        Text020: Label 'Location must be %1, this transaction have %2';
        Text023: Label 'Información enviada a pos de BAC';
        RetailSetup: Record "LSC Retail Setup";
        POSCardIntegration: Codeunit "FSN POS Card Integration";
        POSCardExternalCnn: codeunit "FSN Card External Conextion";
        POSCardEntryRequest2: Record "FSN POS Card Request Entry";
        Amount: Decimal;

    procedure CheckReverse(pRec: Record "FSN POS Card Request Entry"): Decimal
    var
        DelOrder: Record "LSC Delivery Order";
    begin
        IF DelOrder.GET(pRec."Receipt No.") THEN
            ERROR(STRSUBSTNO(Text019, DelOrder."Order No.", DelOrder."Phone No."));

        EXIT(POSCardIntegration.CheckRemaining(pRec));
    end;
}

