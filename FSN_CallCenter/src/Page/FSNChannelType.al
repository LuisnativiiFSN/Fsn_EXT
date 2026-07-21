page 50097 "FSN Channel Links type"
{
    PageType = Card;
    SourceTable = "FSN POS Setup Extend";
    Editable = false;
    UsageCategory = Administration;
    Caption = 'Canal de Ventas';


    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("Store No."; "Store No.")
                {
                    Visible = false;
                    Caption = 'CodeArea';
                }
                field("Line No."; "Line No.")
                {
                    Visible = false;
                    trigger OnLookup(var Text: Text): Boolean
                    var
                        Types: Record "FSN POS Setup Extend";
                        Actionl: Action;
                    begin
                        Types.RESET;
                        Types.SETRANGE(Types.Type, Types.Type::CallCenter);
                        Types.SETRANGE(Types."Line Type", Types."Line Type"::Parameter);
                        Types.SETRANGE(Types."Value No.", 'CHANNELTYPE');
                        Actionl := PAGE.RUNMODAL(PAGE::"FSN Call Center Channel Type", Types);
                        IF Actionl = ACTION::LookupOK THEN BEGIN
                            "Line No." := Types."Line No.";
                            Description := Types."Data Extra 1";
                        END;
                    end;
                }
                field(Description; Description)
                {

                    Caption = 'Canal de Ventas';
                }
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(Aplicar)
            {
                ApplicationArea = All;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        CLEAR(Description);
        POSSetupExtend.RESET;
        POSSetupExtend.SETRANGE(POSSetupExtend.Type, POSSetupExtend.Type::CallCenter);
        POSSetupExtend.SETRANGE(POSSetupExtend."Line Type", POSSetupExtend."Line Type"::Parameter);
        POSSetupExtend.SETRANGE(POSSetupExtend."Value No.", 'CHANNELTYPE');
        POSSetupExtend.SETRANGE(POSSetupExtend."Line No.", "Line No.");
        POSSetupExtend.SETRANGE(POSSetupExtend."Store No.", '');
        IF POSSetupExtend.FIND('-') THEN
            Description := POSSetupExtend."Data Extra 1";
    end;


    trigger OnClosePage()

    var
        InfocodeSelection: Record "LSC Infocode";
        lJsonBuffer: Record "JSON Buffer" temporary;
        JsonTextReader: Codeunit "Json Text Reader/Writer";
        RecCode: Code[20];
        Description: Text[50];
        InfocodeRef: RecordRef;
        InfoKey: RecordId;
        jArray: JsonArray;
        jString: text;
        Ok: Boolean;
        POSGUI: Codeunit "LSC POS GUI";
        StepProcess: Option Input,ByStaff,All;
        POSInfocodeTmpAll: Record "LSC Infocode" temporary;
        POSInfocodeTmpStaff: Record "LSC Infocode" temporary;
        CallCont: Codeunit "FSN CallCenter Controller";
        OrderNo: Code[20];
        DeliveryOrder: Record "LSC Delivery Order";
        FSNSalesChannel: Record "FSN Sales Channel";

    begin

        IF DeliveryOrder.GET(POSSESSION.GetValue('CURRORDER')) then begin
            OrderNo := DeliveryOrder."Order No.";
        end;
        /* Clear(Description);
         Clear(jArray);
         Clear(Ok);
         InfocodeRef.GetTable(InfocodeSelection);
         POSGUI.GetActiveLookupMarkedRecords(jArray, false);
         jArray.WriteTo(jString);
         if jString = '[]' then begin
             jString := '["LSC Infocode: 0"]';
         end;
         JsonTextReader.ReadJSonToJSonBuffer(jString, lJsonBuffer);
         if lJsonBuffer.Find('-') then
             repeat
                 if lJsonBuffer."Token type" = lJsonBuffer."Token type"::String then
                     if lJsonBuffer.Value <> '' then begin
                         EVALUATE(InfoKey, lJsonBuffer.Value);
                         InfocodeRef := InfoKey.GetRecord();
                         if CopyStr(InfocodeRef.Field(InfocodeSelection.FieldNo(Code)).Value, 1, 1) = '.' then begin
                             exit;
                         end;

                         if StepProcess = StepProcess::ByStaff then begin
                             RecCode := InfocodeRef.Field(InfocodeSelection.FieldNo(Code)).Value;
                             if POSInfocodeTmpStaff.Get(RecCode) then;
                             Description := POSInfocodeTmpStaff.Description;
                         end else begin
                             RecCode := InfocodeRef.Field(InfocodeSelection.FieldNo(Code)).Value;
                             if POSInfocodeTmpAll.Get(RecCode) then;
                             Description := POSInfocodeTmpAll.Description;
                         end;

                         SaveChannel(OrderNo
                             , Format(POSSetupExtend."Line No.")
                             , POSSetupExtend."Data Extra 1"
                             , false, '');
                     end;
             until lJsonBuffer.Next() = 0;*/

        SaveChannel(OrderNo
                    , Format(POSSetupExtend."Line No.")
                    , POSSetupExtend."Data Extra 1"
                    , false, '');
        //InfocodeRef.Close();
        if not FSNSalesChannel.Get(DeliveryOrder."Order No.") then begin
            exit;
        end;
    end;


    var
        Description: Text[50];
        POSSetupExtend: Record "FSN POS Setup Extend";
        POSGUI: Codeunit "LSC POS GUI";
        POSSESSION: Codeunit "LSC POS Session";

    procedure SaveChannel(Receipt: Code[20]; ResulText: Text; ResulDescription: Text; pPendingProcess: Boolean; pTicketNo: Code[30])
    var
        cDelOrder: Record "LSC Delivery Order";
        pDelOrder: Record "LSC Posted Delivery Order";
        SalesChan: Record "FSN Sales Channel";
        TransHdr: Record "LSC Transaction Header";
        POSTrans_l: Record "LSC POS Transaction";
        Exists: Boolean;
        Text010: Label 'El canal seleccionado es: %1 %2';
        Text016: Label '¿Desea continuar?';

    begin

        IF (pTicketNo = '##DEFAULT') AND POSTrans_l.GET(Receipt) THEN BEGIN
            Exists := TRUE;
            CLEAR(cDelOrder);
            cDelOrder.INIT;
            cDelOrder."Order No." := POSTrans_l."Receipt No.";
            cDelOrder."Restaurant No." := POSTrans_l."Store No.";
            cDelOrder."Phone No." := POSTrans_l."Sell-to Contact No.";
            cDelOrder."Order Date" := POSTrans_l."Trans. Date";
            cDelOrder."Contact Pickup Time" := POSTrans_l."Trans Time";
            cDelOrder."Order Taker" := POSTrans_l."Sales Staff";
            POSTrans_l.CALCFIELDS(POSTrans_l.Payment);
            cDelOrder."Amount Incl. VAT" := POSTrans_l.Payment;
        END
        ELSE BEGIN
            CLEAR(Exists);
            IF NOT cDelOrder.GET(Receipt) THEN BEGIN
                IF pDelOrder.GET(Receipt) THEN BEGIN
                    CLEAR(cDelOrder);
                    cDelOrder.INIT;
                    cDelOrder."Order No." := pDelOrder."Order No.";
                    cDelOrder."Restaurant No." := pDelOrder."Restaurant No.";
                    cDelOrder."Phone No." := pDelOrder."Phone No.";
                    cDelOrder."Order Date" := pDelOrder."Order Date";
                    cDelOrder."Contact Pickup Time" := pDelOrder."Contact Pickup Time";
                    cDelOrder."Order Taker" := pDelOrder."Order Taker";
                    cDelOrder."Amount Incl. VAT" := pDelOrder."Amount Incl. VAT";
                    Exists := TRUE;
                END;
            END ELSE
                Exists := TRUE;
        END;
        SalesChan.INIT;
        SalesChan."Receipt No" := cDelOrder."Order No.";
        SalesChan."POS Terminal No" := '';
        SalesChan."Store No" := cDelOrder."Restaurant No.";
        SalesChan.PhoneNo := cDelOrder."Phone No.";
        SalesChan.Date := cDelOrder."Order Date";
        SalesChan.Time := cDelOrder."Contact Pickup Time";
        SalesChan.SalesStaff := cDelOrder."Order Taker";
        SalesChan."Amount Incl. VAT" := cDelOrder."Amount Incl. VAT";
        SalesChan.TypeChannel := ResulText;
        SalesChan.SalesChannel := Description;
        SalesChan."Pending Processing" := pPendingProcess;
        SalesChan.Ticket := pTicketNo;
        SalesChan.Voided := NOT Exists;
        IF not CONFIRM(STRSUBSTNO(Text010, Description, Text016)) THEN begin
            exit
        end else begin
            IF pTicketNo = '##DEFAULT' THEN
                SalesChan.Comment := 'Automatic';
            IF NOT SalesChan.INSERT(TRUE) THEN
                SalesChan.MODIFY(TRUE);
        end;
    end;
}

