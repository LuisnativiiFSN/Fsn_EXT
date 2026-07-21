codeunit 50028 "FSN Ecommerce CallCenter Mgt."
{
    TableNo = "LSC POS Menu Line";
    trigger OnRun()
    begin
        case Command of
            'SEND_ORDERBACKUP':
                SendOrderBackup(Rec);//Internal process
            'SENDDELIVERYBACKUP':
                SendDeliveryBackup("Current-RECEIPT");
            'TESTCC':
                BEGIN
                    document := document.XmlDocument();
                    ParameterEcommerce.GET('ECOMMERCE', 'MANUAL');
                    document.Load(ParameterEcommerce."Web Uri");
                    ValueNode := document.OuterXml();

                    //Efun.SendPosTransRequestEcommerce('SEND_POSTRANS_BACKUP', ValueNode, ERROR);
                    Efun.SendPosTransRequest('SEND_POSTRANS_BACKUP_BC', ValueNode, ERROR);
                    //SendDeliveryBackup(Rec.Parameter);
                    //del.UpdateTRansaction(Rec.Parameter);
                END;
        end;
    end;

    var
        ParameterEcommerce: Record "FSN Parameter";
        del: Codeunit "FSN Ecommerce Functions";
        document: DotNet XmlDocument;
        ValueNode: Text;
        Efun: Codeunit "FSN Ecommerce Functions";
        ERROR: Text;
        Tiendas: Text;

    procedure SendOrderBackup(pParameters: Record "LSC POS Menu Line")
    var
        DelPosCommand: Codeunit "LSC Delivery POS Commands";
        ErrorText: Text[1024];
        pError: Boolean;
        FSNSalesChannel: Codeunit "FSN CallCenter Controller";
        FSNDeliveryFuncExt: Codeunit "FSN Delivery Functions Extend";
        fsnUtility: Codeunit "FSN Utility";
        //variables for utility functions
        request, response, ID, result : Text;
        menuLine: Record "LSC POS Menu Line";
        processed: Boolean;
    begin

        DeliveryOrderBK.RESET;
        CLEAR(DeliveryOrderBK);
        Clear(ErrorText);

        IF NOT InitTablesBackup(pParameters) THEN
            EXIT;

        POSSESSION.SetStore(CCPOSTermBK."Restaurant No.");
        POSSESSION.SetTerminal(CCPOSTermBK."Rest. POS Terminal");

        IF NOT ValidateServerInventoryTR(CSWebServiceTableBK.LastSlipNo, CSWebServiceTableBK."Store Selected", pError, ErrorText) THEN BEGIN
            SetErrorOrderBackup(pParameters."Current-RECEIPT", '0070');
            EXIT;
        END;

        IF NOT InitDeliveryBackup(pParameters) THEN BEGIN
            SetErrorOrderBackup(pParameters."Current-RECEIPT", '0061');
            EXIT;
        END;
        IF HospitalitySetupBK."Populate Delivery Infocodes" = 1 THEN
            InitPopulateInfocodes();

        FSNDeliveryFuncExt.ChangeStore(DeliveryOrderBK."Order No.", CSWebServiceTableBK."Store Selected", 3);//WS = 3

        FSNSalesChannel.TestSalesChannel(DeliveryOrderBK);//SalesChannel



        IF DeliveryOrderBK.INSERT THEN BEGIN
            IF NOT DelPosCommand.SendDeliveryOrder(DeliveryOrderBK, FALSE, ErrorText) THEN BEGIN
                SetErrorOrderBackup(pParameters."Current-RECEIPT", '0099');
                IF POSTransactionBK.GET(pParameters."Current-RECEIPT") THEN BEGIN
                    POSTransactionBK."Entry Status" := POSTransactionBK."Entry Status"::Suspended;
                    POSTransactionBK.MODIFY;
                    IF CSWebServiceTableBK.GET(pParameters."Current-RECEIPT") THEN BEGIN
                        CSWebServiceTableBK."Status WS" := CSWebServiceTableBK."Status WS"::Pending;//Return status
                        CSWebServiceTableBK.MODIFY;
                    END;
                END;
                IF DeliveryOrderBK.GET(pParameters."Current-RECEIPT") THEN
                    DeliveryOrderBK.DELETE;
            END ELSE BEGIN
                SetErrorOrderBackup(pParameters."Current-RECEIPT", 'SENT');
                IF DeliveryOrderBK.GET(pParameters."Current-RECEIPT") THEN BEGIN
                    DeliveryOrderBK."Call Cent. Web Service Status" := 4;
                    DeliveryOrderBK.MODIFY;
                END;
                //? aqui en el codigo original hay un commit
                // Commit();
                if CSWebServiceTableBK."Order Type" = CSWebServiceTableBK."Order Type"::Delivery then begin
                    //DAF.createDelivery(DeliveryOrderBK);
                    request := DeliveryOrderBK."Order No.";
                    ID := 'CREATE_DELIVERY_CALL';
                    fsnUtility.InvokeGlobalChannel(request, response, ID, menuLine, processed, result);
                end;
            END;
        END ELSE BEGIN
            POSTransactionBK."Entry Status" := POSTransactionBK."Entry Status"::Suspended;
            POSTransactionBK.MODIFY;
            IF CSWebServiceTableBK.GET(pParameters."Current-RECEIPT") THEN BEGIN
                CSWebServiceTableBK."Status WS" := CSWebServiceTableBK."Status WS"::Pending;//Return status
                CSWebServiceTableBK.MODIFY;
            END;

        END;
        COMMIT;
    end;

    local procedure InitTablesBackup(pParameters: Record "LSC POS Menu Line"): Boolean
    var
        StaffDefault: Code[20];
        POSLine: Record "LSC POS Trans. Line";
        Tender: Record "LSC Tender Type Setup";
        POSCardEntries: Record "LSC POS Card Entry";
        Item_l: Record "Item";
    begin

        CSWebServiceTableBK.RESET;
        CSWebServiceTableBK.SETRANGE(CSWebServiceTableBK.LastSlipNo, pParameters."Current-RECEIPT");
        IF NOT CSWebServiceTableBK.FIND('-') THEN BEGIN
            SetErrorOrderBackup(pParameters."Current-RECEIPT", '0030');
            EXIT(FALSE);
        END;
        POSSetupExtBK.Reset();
        POSSetupExtBK.SetRange("Type", POSSetupExtBK."Type"::CallCenter);
        POSSetupExtBK.SetRange("Line Type", POSSetupExtBK."Line Type"::Parameter);
        IF StrPos(CSWebServiceTableBK.LastSlipNo, '0000000APP') > 0 then
            POSSetupExtBK.SetRange("Value No.", 'STAFFAPP')
        ELSE
            POSSetupExtBK.SetRange("Value No.", 'STAFFEC');
        if POSSetupExtBK.Find('-') then
            StaffDefault := POSSetupExtBK."Value Reference No."
        else
            StaffDefault := 'F20';

        POSLine.RESET;
        POSLine.SETRANGE(POSLine."Receipt No.", CSWebServiceTableBK.LastSlipNo);
        POSLine.SETRANGE(POSLine."Entry Type", POSLine."Entry Type"::Item);
        POSLine.SETRANGE(POSLine."Entry Status", 0);
        IF POSLine.FIND('-') THEN
            REPEAT
                IF Item_l.GET(POSLine.Number) THEN
                    IF Item_l."LSC Attrib 2 Code" IN ['CONTROLADOS', 'MONOFARMACO-CONTROLADO', 'POLIFARMACO-CONTROLADO'] THEN BEGIN
                        SetErrorOrderBackup(pParameters."Current-RECEIPT", '0064');
                        EXIT(FALSE);
                    END;
            UNTIL POSLine.NEXT = 0;

        IF CSWebServiceTableBK."Order Type" IN [CSWebServiceTableBK."Order Type"::Delivery,
                                                CSWebServiceTableBK."Order Type"::Takeaway] THEN
            IF CSWebServiceTableBK."Distribution Location" <> '' then
                POSSESSION.SetStaff('BOT')
            else
                POSSESSION.SetStaff(StaffDefault);


        IF NOT (CSWebServiceTableBK."Order Type" IN [CSWebServiceTableBK."Order Type"::Takeaway,
                                                    CSWebServiceTableBK."Order Type"::Delivery]) THEN BEGIN
            SetErrorOrderBackup(pParameters."Current-RECEIPT", '0031');
            EXIT(FALSE);
        END;

        IF NOT POSTransactionBK.GET(pParameters."Current-RECEIPT") THEN BEGIN
            SetErrorOrderBackup(pParameters."Current-RECEIPT", '0010');
            EXIT(FALSE);
        END;

        IF DeliveryOrderBK.GET(pParameters."Current-RECEIPT") THEN BEGIN
            SetErrorOrderBackup(pParameters."Current-RECEIPT", '0020');
            EXIT(FALSE);
        END;

        DelContactAddressBK.RESET;
        DelContactAddressBK.SETRANGE(DelContactAddressBK."Phone No.", CSWebServiceTableBK."Sell-to Contact No.");
        IF NOT DelContactAddressBK.FIND('+') OR NOT ContacBK.GET(CSWebServiceTableBK."Sell-to Contact No.") THEN
            SetInsertDelContact(CSWebServiceTableBK);

        DelContactAddressBK.RESET;
        DelContactAddressBK.SETRANGE(DelContactAddressBK."Phone No.", CSWebServiceTableBK."Sell-to Contact No.");
        IF NOT DelContactAddressBK.FINDFIRST THEN BEGIN
            SetErrorOrderBackup(pParameters."Current-RECEIPT", '0040');
            EXIT(FALSE);
        END;
        IF NOT ContacBK.GET(CSWebServiceTableBK."Sell-to Contact No.") THEN BEGIN
            SetErrorOrderBackup(pParameters."Current-RECEIPT", '0050');
            EXIT(FALSE);
        END;


        IF CSWebServiceTableBK.Mail <> '' THEN BEGIN
            ContacBK."E-Mail" := COPYSTR(CSWebServiceTableBK.Mail, 1, MAXSTRLEN(ContacBK."E-Mail"));
            ContacBK.MODIFY;
        END;
        IF NOT InitDelContactAddress() THEN BEGIN
            SetErrorOrderBackup(pParameters."Current-RECEIPT", '0051');
            EXIT(FALSE);
        END;



        IF NOT HospitalitySetupBK.GET OR NOT RetailSetupBK.GET THEN BEGIN
            SetErrorOrderBackup(pParameters."Current-RECEIPT", '0061');
            EXIT(FALSE);
        END;

        IF NOT CCPOSTermBK.GET(RetailSetupBK."Local Store No.", CSWebServiceTableBK."Store Selected") THEN BEGIN
            SetErrorOrderBackup(pParameters."Current-RECEIPT", '0060');
            EXIT(FALSE);
        END;

        POSTransactionBK.CALCFIELDS(Payment);
        IF POSTransactionBK.Payment <> CSWebServiceTableBK.Amount THEN BEGIN
            SetErrorOrderBackup(pParameters."Current-RECEIPT", '0062');
            EXIT(FALSE);
        END;

        POSLine.RESET;
        POSLine.SETRANGE(POSLine."Receipt No.", CSWebServiceTableBK.LastSlipNo);
        POSLine.SETRANGE(POSLine."Entry Type", POSLine."Entry Type"::Payment);
        POSLine.SETRANGE(POSLine."Entry Status", 0);
        IF POSLine.FIND('-') THEN
            REPEAT
                IF Tender.GET(POSLine.Number) THEN
                    IF Tender."FSN Function in CC" = Tender."FSN Function in CC"::Card THEN
                        IF NOT POSCardEntries.GET(POSLine."Store No.", POSLine."POS Terminal No.", POSLine."Receipt No.", POSLine."Line No.") THEN BEGIN
                            SetErrorOrderBackup(pParameters."Current-RECEIPT", '0063');
                            EXIT(FALSE);
                        END;
            UNTIL POSLine.NEXT = 0;

        IF (CSWebServiceTableBK."Order Type" = CSWebServiceTableBK."Order Type"::Delivery) OR
(CSWebServiceTableBK."Order Type" = CSWebServiceTableBK."Order Type"::Takeaway) THEN
            ValExistsCustomer(CSWebServiceTableBK);
        EXIT(TRUE);
    end;

    procedure ValExistsCustomer(CSWebServiceTableVal: Record "FSN WebServiceTable")
    var
        CustomerVal: Record Customer;
        ValDUI: Text[20];
    begin

        ValDUI := '';
        //IF CSWebServiceTableVal."Customer No." <> '' THEN BEGIN
        IF CSWebServiceTableVal."Document Personal" <> '' THEN BEGIN
            IF STRLEN(CSWebServiceTableVal."Document Personal") = 10 THEN BEGIN
                CustomerVal.RESET;
                CustomerVal.SETRANGE(CustomerVal."FSN DUI", CSWebServiceTableVal."Document Personal");
                IF CustomerVal.FINDFIRST THEN
                    ValCreateNewCustomer(CSWebServiceTableVal, true, CustomerVal."No.")
                ELSE
                    ValCreateNewCustomer(CSWebServiceTableVal, false, '');
            END ELSE BEGIN
                IF STRLEN(CSWebServiceTableVal."Document Personal") = 9 THEN BEGIN
                    ValDUI := COPYSTR(CSWebServiceTableVal."Document Personal", 1, 8) + '-' + COPYSTR(CSWebServiceTableVal."Document Personal", 9);
                    CSWebServiceTableVal."Document Personal" := ValDUI;
                    CSWebServiceTableVal.MODIFY;

                    CustomerVal.RESET;
                    CustomerVal.SETRANGE(CustomerVal."FSN DUI", ValDUI);
                    IF CustomerVal.FINDFIRST THEN
                        ValCreateNewCustomer(CSWebServiceTableVal, true, CustomerVal."No.")
                    ELSE
                        ValCreateNewCustomer(CSWebServiceTableVal, false, '');
                END;
            END;
        END ELSE BEGIN
            IF CSWebServiceTableVal."Sell-to Contact No." <> '' THEN BEGIN
                CustomerVal.RESET;
                CustomerVal.SETRANGE(CustomerVal."Phone No.", CSWebServiceTableVal."Sell-to Contact No.");
                IF CustomerVal.FINDFIRST THEN BEGIN
                    IF CustomerVal."E-Mail" <> CSWebServiceTableVal.Mail THEN
                        ValCreateNewCustomer(CSWebServiceTableVal, false, '')
                    ELSE
                        ValCreateNewCustomer(CSWebServiceTableVal, true, CustomerVal."No.");
                END;
            END;
        END;
        //END;
    end;


    procedure ValCreateNewCustomer(VCSWebServiceTable: Record "FSN WebServiceTable"; modifyClient: Boolean; CodeCustomerVal: Code[20])
    var
        NewCustomer: Record Customer;
        ValSerie: Record "No. Series";
        NoSeriesManagement: Codeunit NoSeriesManagement;
        NoSerieCust: Code[20];
        Functionality: Record "LSC POS Func. Profile";
        CustomerTemplate: Record Customer;
    begin
        Functionality.Get('#FASANI');
        IF NOT modifyClient THEN BEGIN
            IF CustomerTemplate.get(Functionality."New Customer Defaults") tHEN BEGIN
                NewCustomer := CustomerTemplate;
                NewCustomer."No." := '';
                NewCustomer.Name := VCSWebServiceTable."First Name" + ' ' + VCSWebServiceTable."Last Name";
                NewCustomer."Phone No." := VCSWebServiceTable."Sell-to Contact No.";
                NewCustomer."FSN DUI" := VCSWebServiceTable."Document Personal";
                NewCustomer."E-Mail" := VCSWebServiceTable.Mail;
                NewCustomer.INSERT(TRUE);
            END;
        END ELSE BEGIN
            IF NewCustomer.GET(CodeCustomerVal) tHEN BEGIN
                IF NewCustomer."E-Mail" <> VCSWebServiceTable.Mail THEN
                    NewCustomer."E-Mail" := VCSWebServiceTable.Mail;
                IF NewCustomer.Name <> VCSWebServiceTable."First Name" + ' ' + VCSWebServiceTable."Last Name" THEN
                    NewCustomer.Name := VCSWebServiceTable."First Name" + ' ' + VCSWebServiceTable."Last Name";
                NewCustomer.MODIFY;
                Message(NewCustomer."No.");
            END;
        END;
    end;

    procedure ValOrderStatus(ReceipVal: Code[20]; Store: Code[10]; Terminal: Code[10])
    var
        ValTransHeader: Record "LSC Transaction Header";
        ValPosTransaction: Record "LSC Pos Transaction";
        DelOrderV: Record "LSC Delivery Order";

    begin
        ValTransHeader.Reset();
        ValTransHeader.SetRange(ValTransHeader."Store No.", Store);
        ValTransHeader.SetRange(ValTransHeader."POS Terminal No.", Terminal);
        ValTransHeader.SetRange(ValTransHeader."Receipt No.", ReceipVal);
        if ValTransHeader.FindFirst() then begin
            if ValTransHeader."Entry Status" = ValTransHeader."Entry Status"::" " then begin
                if DelOrderV.Get(ReceipVal) then
                    DelOrderV.Delete(true);
                if ValPosTransaction.get(ValTransHeader."Receipt No.") then
                    ValPosTransaction.Delete(true);
            end;
        end;
    end;

    local procedure InitDeliveryBackup(pParameters: Record "LSC POS Menu Line"): Boolean
    var
        TenderTypeSetup_l: Record "LSC Tender Type Setup";
    begin
        DeliveryOrderBK.INIT;
        DeliveryOrderBK."Order No." := POSTransactionBK."Receipt No.";
        DeliveryOrderBK."Phone No." := DelContactAddressBK."Phone No.";
        DeliveryOrderBK."Order Date" := TODAY;
        DeliveryOrderBK."Contact Pickup Time" := TIME;
        DeliveryOrderBK.Address := DelContactAddressBK."Street No." + ' ' + DelContactAddressBK."Street Name";
        DeliveryOrderBK."Address 2" := DelContactAddressBK."Address 2";
        DeliveryOrderBK.City := DeliveryStreetBK.City;
        DeliveryOrderBK."Order Taker" := POSSESSION.StaffID();
        DeliveryOrderBK."Restaurant No." := CSWebServiceTableBK."Store Selected";
        DeliveryOrderBK.Name := ContacBK.Name;
        DeliveryOrderBK."Estimated Prod. Time (Min.)" := DeliveryStreetBK."Delivery Time (Min.)";
        CASE CSWebServiceTableBK."Order Type" OF
            CSWebServiceTableBK."Order Type"::Delivery,
          CSWebServiceTableBK."Order Type"::HomeOfficeDelivery,
          CSWebServiceTableBK."Order Type"::FromStoreDelivery:
                DeliveryOrderBK."Sales Type" := HospitalitySetupBK."Delivery Sales Type";
            CSWebServiceTableBK."Order Type"::Takeaway,
          CSWebServiceTableBK."Order Type"::HomeOfficeTakeaway,
          CSWebServiceTableBK."Order Type"::FromStoreTakeaway:
                DeliveryOrderBK."Sales Type" := HospitalitySetupBK."Takeout Sales Type";
            ELSE
                EXIT(FALSE);
        END;

        POSTransLineBK.Reset();
        POSTransLineBK.SetCurrentKey("Receipt No.", "Entry Type", "Entry Status");
        POSTransLineBK.SetRange("Receipt No.", POSTransactionBK."Receipt No.");
        POSTransLineBK.SetRange("Entry Type", POSTransLineBK."Entry Type"::Payment);
        POSTransLineBK.SetRange("Entry Status", POSTransLineBK."Entry Status"::" ");
        case POSTransLineBK.Count() of
            0:
                begin
                    DeliveryOrderBK."Amount Incl. VAT" := 0;
                    DeliveryOrderBK."Tender Type" := DeliveryOrderBK."Tender Type"::None;
                end;
            1:
                begin
                    POSTransLineBK.FindFirst();
                    DeliveryOrderBK."Amount Incl. VAT" := POSTransLineBK.Amount;
                    if TenderTypeSetup_l.Get(POSTransLineBK.Number) then
                        case TenderTypeSetup_l."FSN Function in CC" of
                            TenderTypeSetup_l."FSN Function in CC"::Card,
                            TenderTypeSetup_l."FSN Function in CC"::CrossCard:
                                DeliveryOrderBK."Tender Type" := DeliveryOrderBK."Tender Type"::Card;
                            TenderTypeSetup_l."FSN Function in CC"::Change,
                            TenderTypeSetup_l."FSN Function in CC"::Check,
                            TenderTypeSetup_l."FSN Function in CC"::CrossCash,
                            TenderTypeSetup_l."FSN Function in CC"::Normal:
                                DeliveryOrderBK."Tender Type" := DeliveryOrderBK."Tender Type"::Cash;
                            TenderTypeSetup_l."FSN Function in CC"::CustomerAccount:
                                DeliveryOrderBK."Tender Type" := DeliveryOrderBK."Tender Type"::Invoice;
                            TenderTypeSetup_l."FSN Function in CC"::Member:
                                DeliveryOrderBK."Tender Type" := DeliveryOrderBK."Tender Type"::Prepaid;
                        end
                end;
            else begin
                POSTransLineBK.CalcSums(Amount);
                DeliveryOrderBK."Amount Incl. VAT" := POSTransLineBK.Amount;
                DeliveryOrderBK."Tender Type" := DeliveryOrderBK."Tender Type"::Prepaid;
            end;
        end;

        DeliveryOrderBK."Date Created" := TODAY;
        DeliveryOrderBK."Time Created" := TIME;
        DeliveryOrderBK."Created at Call Center" := RetailSetupBK."Local Store No.";
        DeliveryOrderBK."Call Cent. Web Service Status" := 10;   //Not confirm
                                                                 //No Choice,Delivery Home,Delivery Work,Delivery Other,Takeout
        DeliveryOrderBK."Order Type Option" := ContacBK."LSC Next Order Selection";
        DeliveryOrderBK."Post Code" := DelContactAddressBK."Post Code";
        DeliveryOrderBK.Directions := DelContactAddressBK.Directions;
        DeliveryOrderBK."Grid Code" := DelContactAddressBK."Grid Code";
        DeliveryOrderBK."FSN Confirm Date" := TODAY;
        DeliveryOrderBK."FSN Confirm Time" := Time;
        IF CSWebServiceTableBK."Order Type" IN [CSWebServiceTableBK."Order Type"::Delivery,
                                                CSWebServiceTableBK."Order Type"::Takeaway] THEN BEGIN
            DeliveryOrderBK."External Order No." := CSWebServiceTableBK."Order No.";
        END;
        POSTransactionBK."Sales Type" := DeliveryOrderBK."Sales Type";
        POSTransactionBK.Comment := DeliveryOrderBK.Name;
        POSTransactionBK.MODIFY;

        EXIT(TRUE);
    end;

    local procedure InitDelContactAddress(): Boolean
    var
        POSInfocodeEntry: Record "LSC POS Trans. Infocode Entry";
        POSInfocodeEntry2: Record "LSC POS Trans. Infocode Entry";
        POSInfocodeEntry3: Record "LSC POS Trans. Infocode Entry";
        POSInfocodeEntry4: Record "LSC POS Trans. Infocode Entry";
        PostCode_l: Record "Post Code";
        DeliveryStreet_l: Record "LSC Delivery Street";
        Phone: Code[20];
        TypeInt: Integer;
        TypeText: Text;
        StrPosStart: Integer;
        StrPosEnd: Integer;
        StrPosCountry: Integer;
        StreetExtists: Boolean;
        Country: Text[100];
        City: Text[100];
        StreetName: Text[250];
        PostCode: Code[20];
    begin
        CLEAR(StreetName);
        CLEAR(City);
        CLEAR(Country);
        CLEAR(StrPosStart);
        CLEAR(StrPosEnd);
        DelContactAddressBK.RESET;
        CLEAR(DelContactAddressBK);
        POSInfocodeEntry.RESET;

        IF CSWebServiceTableBK."Order Type" IN [CSWebServiceTableBK."Order Type"::Takeaway,
                                                CSWebServiceTableBK."Order Type"::HomeOfficeTakeaway,
                                                CSWebServiceTableBK."Order Type"::FromStoreTakeaway] THEN BEGIN
            IF NOT DelContactAddressBK.GET(ContacBK."No.", 3) THEN BEGIN
                DelContactAddressBK.INIT;
                DelContactAddressBK."Phone No." := ContacBK."No.";
                DelContactAddressBK."Address Type" := 3;
                DelContactAddressBK."Restaurant No." := CSWebServiceTableBK."Store Selected";
                DelContactAddressBK.INSERT(TRUE);

                CLEAR(DeliveryStreetBK);
            END;
        END ELSE BEGIN

            /*IF NOT POSInfocodeEntry.GET(CSWebServiceTableBK.LastSlipNo, 0, 888, 'TEXT', 0) THEN
                EXIT(FALSE);*/

            Phone := BOUTIL.SeparateCombinedValue(1, POSInfocodeEntry.Information);
            TypeText := BOUTIL.SeparateCombinedValue(2, POSInfocodeEntry.Information);
            IF NOT EVALUATE(TypeInt, TypeText) THEN
                EXIT(FALSE);

            IF TypeInt = 2 THEN BEGIN
                IF NOT POSInfocodeEntry2.GET(CSWebServiceTableBK.LastSlipNo, 0, 6, 'DDIRECTION', 0) OR
                  (POSInfocodeEntry2.Information = '') THEN
                    EXIT(FALSE);
                IF NOT POSInfocodeEntry3.GET(CSWebServiceTableBK.LastSlipNo, 0, 888, 'TEXT', 0) OR
                  (POSInfocodeEntry3.Information = '') THEN
                    EXIT(FALSE);
                IF NOT POSInfocodeEntry4.GET(CSWebServiceTableBK.LastSlipNo, 0, 889, 'TEXT', 0) OR
              (POSInfocodeEntry4.Information = '') THEN
                    EXIT(FALSE);

            END;
            IF TypeInt <> 2 THEN
                IF NOT DelContactAddressBK.GET(Phone, TypeInt) THEN
                    EXIT(FALSE)
                ELSE
                    IF DelContactAddressBK."Street Name" = '' THEN
                        EXIT(FALSE);

            TypeText := '';
            StrPosStart := STRPOS(POSInfocodeEntry2.Information, ' (');
            StrPosEnd := STRPOS(POSInfocodeEntry2.Information, ')');

            IF (StrPosStart > 0) AND (StrPosEnd > StrPosStart) THEN BEGIN
                StreetName := COPYSTR(POSInfocodeEntry2.Information, 1, STRPOS(POSInfocodeEntry2.Information, ' (') - 1);
                TypeText := COPYSTR(POSInfocodeEntry2.Information, STRPOS(POSInfocodeEntry2.Information, ' (') + 2, STRPOS(POSInfocodeEntry2.Information, ')'));

                StrPosStart := STRPOS(TypeText, ',');
                StrPosEnd := STRPOS(TypeText, ')');

                Country := COPYSTR(TypeText, 1, STRPOS(TypeText, ',') - 1);
                City := COPYSTR(TypeText, STRPOS(TypeText, ',') + 1, StrPosEnd - (STRPOS(TypeText, ',') + 1));
            END;
            IF (StreetName = '') OR (Country = '') OR (City = '') THEN
                EXIT(FALSE);

            StreetExtists := FALSE;
            IF TypeInt = 2 THEN BEGIN

                PostCode := '';
                PostCode_l.RESET;
                PostCode_l.SETCURRENTKEY("Search City");
                PostCode_l.SETRANGE(PostCode_l."Search City", UPPERCASE(City));
                IF PostCode_l.FIND('-') THEN
                    REPEAT
                        IF UPPERCASE(PostCode_l.County) = Country THEN
                            PostCode := PostCode_l.Code;
                    UNTIL (PostCode_l.NEXT = 0) OR (PostCode <> '');

                IF PostCode = '' THEN
                    EXIT(FALSE);

                DeliveryStreet_l.RESET;
                DeliveryStreet_l.SETCURRENTKEY("Street Name", "Number from", "Post Code");
                DeliveryStreet_l.SETRANGE(DeliveryStreet_l."Street Name", StreetName);
                DeliveryStreet_l.SETRANGE(DeliveryStreet_l."Post Code", PostCode);
                IF DeliveryStreet_l.FINDFIRST THEN
                    StreetExtists := DeliveryStreetBK.GET(DeliveryStreet_l."Street Name", DeliveryStreet_l."Number from", DeliveryStreet_l."Post Code");
            END;

            IF TypeInt = 2 THEN BEGIN
                IF NOT DelContactAddressBK.GET(Phone, TypeInt) THEN begin
                    DelContactAddressBK.INIT();
                    DelContactAddressBK."Phone No." := Phone;
                    DelContactAddressBK."Address Type" := TypeInt;
                end;
                DelContactAddressBK."Street Name" := DeliveryStreetBK."Street Name";
                DelContactAddressBK."Street No." := FORMAT(DeliveryStreetBK."Number from");
                DelContactAddressBK."Post Code" := DeliveryStreetBK."Post Code";
                DelContactAddressBK.City := City;
                DelContactAddressBK."Address 2" := '';
                DelContactAddressBK.Directions := POSInfocodeEntry4.Information;
                DelContactAddressBK."Restaurant No." := CSWebServiceTableBK."Store Selected";
                DelContactAddressBK."Grid Code" := DeliveryStreetBK."Grid Code";
                IF NOT DelContactAddressBK.INSERT(TRUE) THEN
                    DelContactAddressBK.MODIFY(TRUE);
            END;

        END;

        ContacBK."LSC Next Order Selection" := TypeInt + 1;
        IF CSWebServiceTableBK."Order Type" IN [CSWebServiceTableBK."Order Type"::Takeaway,
                                                CSWebServiceTableBK."Order Type"::HomeOfficeTakeaway,
                                                CSWebServiceTableBK."Order Type"::FromStoreTakeaway] THEN BEGIN
            ContacBK."LSC Next Order Selection" := 4;
            EXIT(TRUE);
        END;

        EXIT(StreetExtists);
    end;

    local procedure InitPopulateInfocodes()
    var
        PosInfocode: Record "LSC POS Trans. Infocode Entry";
    begin
        PosInfocode.INIT;
        PosInfocode."Receipt No." := POSTransactionBK."Receipt No.";
        PosInfocode."Transaction Type" := 0;
        PosInfocode."Line No." := 1;
        PosInfocode.Infocode := 'DNAME';
        PosInfocode.Information := ContacBK.Name;
        PosInfocode."Store No." := CSWebServiceTableBK.Store;
        PosInfocode.Date := TODAY;
        PosInfocode.Time := TIME;
        PosInfocode."POS Terminal No." := CSWebServiceTableBK.Terminal;
        PosInfocode."Staff ID" := POSSESSION.StaffID;
        IF NOT PosInfocode.INSERT(TRUE) THEN
            PosInfocode.MODIFY(TRUE);

        IF DelContactAddressBK."Street Name" <> '' THEN BEGIN
            PosInfocode.Infocode := 'DADDRESS';
            PosInfocode."Line No." := 2;
            PosInfocode.Information := DelContactAddressBK."Street Name";
            IF NOT PosInfocode.INSERT(TRUE) THEN
                PosInfocode.MODIFY(TRUE);
        END;

        IF DeliveryOrderBK."Address 2" <> '' THEN BEGIN
            PosInfocode.Infocode := 'DADDRESS2';
            PosInfocode."Line No." := 3;
            PosInfocode.Information := DelContactAddressBK."Address 2";
            IF NOT PosInfocode.INSERT(TRUE) THEN
                PosInfocode.MODIFY(TRUE);
        END;

        IF DeliveryOrderBK.City <> '' THEN BEGIN
            PosInfocode.Infocode := 'DCITYZIP';
            PosInfocode."Line No." := 4;
            PosInfocode.Information := DeliveryOrderBK.City + ' ' + DeliveryOrderBK."Post Code";
            IF NOT PosInfocode.INSERT(TRUE) THEN
                PosInfocode.MODIFY(TRUE);
        END;

        IF DeliveryOrderBK."Grid Code" <> '' THEN BEGIN
            PosInfocode.Infocode := 'DGRID';
            PosInfocode."Line No." := 5;
            PosInfocode.Information := DeliveryOrderBK."Grid Code";
            IF NOT PosInfocode.INSERT(TRUE) THEN
                PosInfocode.MODIFY(TRUE);
        END;

        IF DeliveryOrderBK.Directions <> '' THEN BEGIN
            PosInfocode.Infocode := 'DDIRECTION';
            PosInfocode."Line No." := 6;
            PosInfocode.Information := DeliveryOrderBK.Directions;
            IF NOT PosInfocode.INSERT(TRUE) THEN
                PosInfocode.MODIFY(TRUE);
        END;
    end;

    local procedure SetErrorOrderBackup(pOrder: Code[20]; pErrorCode: Text[4])
    var
        CSWSTable: Record "FSN WebServiceTable";
        lText000: Label '%1 not exists';
        lText001: Label 'POS Transaction.';
        lText002: Label 'Delivery order alredy exists';
        lText003: Label 'CS Web Service';
        lText004: Label 'Del. Cont. Address';
        lText005: Label 'Contact';
        lText006: Label 'CC Pos Terminal';
        lText007: Label 'Inventory not successfull';
        lText099: Label 'Send order to store Fail';
        lText006_1: Label 'Store config.';
        lText005_1: Label 'Directions in infocode not found!';
        lText003_1: Label 'Order type not applied send.';
        lText008: Label 'Difference amounts';
        PCE: Record "LSC POS Card Entry";
        lText009: Label 'Item attribute 2 block for send';
    begin
        IF NOT CSWSTable.GET(pOrder) THEN
            EXIT;

        CASE pErrorCode OF
            '0010':
                CSWSTable."Last Error Text" := STRSUBSTNO(lText000, lText001);
            '0020':
                CSWSTable."Last Error Text" := lText002;
            '0030':
                CSWSTable."Last Error Text" := STRSUBSTNO(lText000, lText003);
            '0031':
                CSWSTable."Last Error Text" := STRSUBSTNO(lText003_1);
            '0040':
                CSWSTable."Last Error Text" := STRSUBSTNO(lText000, lText004);
            '0050':
                CSWSTable."Last Error Text" := STRSUBSTNO(lText000, lText005);
            '0051':
                CSWSTable."Last Error Text" := STRSUBSTNO(lText005_1);
            '0060':
                CSWSTable."Last Error Text" := STRSUBSTNO(lText000, lText006);
            '0061':
                CSWSTable."Last Error Text" := STRSUBSTNO(lText000, lText006_1);
            '0062':
                CSWSTable."Last Error Text" := lText008;
            '0063':
                CSWSTable."Last Error Text" := STRSUBSTNO(lText000, PCE.TABLECAPTION);
            '0070':
                CSWSTable."Last Error Text" := lText007;
            '0099':
                CSWSTable."Last Error Text" := lText099;
            '0064':
                CSWSTable."Last Error Text" := lText009;
            ELSE
                CSWSTable."Last Error Text" := pErrorCode;
        END;
        IF CSWSTable."Last Error Text" <> '' THEN
            CSWSTable.MODIFY;
    end;

    procedure SetInsertDelContact(pCSWebServicetable: Record "FSN WebServiceTable"): Boolean
    var
        //ExternalOrderFunctions: Codeunit "10001208";
        //ExtOrderIn: Record "POS Transaction";
        ID: Code[20];
    begin

        IF NOT ((pCSWebServicetable."First Name" <> '') OR (pCSWebServicetable."Last Name" <> '')) THEN
            EXIT(FALSE);
        /*
                IF ExtOrderIn.GET(pCSWebServicetable."Order No.") THEN
                    ExtOrderIn.DELETE;

                IF pCSWebServicetable."Order No." = '' THEN
                    IF ExtOrderIn.GET(pCSWebServicetable.LastSlipNo) THEN
                        ExtOrderIn.DELETE;

                ExtOrderIn.INIT;
                IF pCSWebServicetable."Order No." <> '' THEN
                    ExtOrderIn.ID := pCSWebServicetable."Order No."
                ELSE
                    ExtOrderIn.ID := pCSWebServicetable.LastSlipNo;

                ExtOrderIn."Store No." := pCSWebServicetable."Store Selected";
                IF pCSWebServicetable."Order Type" = pCSWebServicetable."Order Type"::Takeaway THEN
                    ExtOrderIn.Type := '2';
                ExtOrderIn."Primary Phone" := pCSWebServicetable."Sell-to Contact No.";
                ExtOrderIn."First Name" := pCSWebServicetable."First Name";
                ExtOrderIn."Last Name" := pCSWebServicetable."Last Name";
                ExtOrderIn."Primary Email" := pCSWebServicetable.Mail;
                ExtOrderIn."Order Time" := CURRENTDATETIME;
                ExtOrderIn."Address Type" := '4';
                ExtOrderIn.INSERT();

                ID := '';
                ID := ExternalOrderFunctions.InsertContactInfoExt(ExtOrderIn);

                IF ExtOrderIn.DELETE THEN;
        *///REVISAR
        ID := InsertContactInfoExt(pCSWebServicetable);
        EXIT(ID <> '');
    end;

    procedure InsertContactInfoExt(ExtOrderIn: Record "FSN WebServiceTable"): Code[20]
    var
        DelCont: Record Contact;
        DelContAddr: Record "LSC Delivery Contact Address";
        DelStreet: Record "LSC Delivery Street";
    begin
        IF ExtOrderIn."Sell-to Contact No." = '' THEN
            EXIT;

        IF NOT DelCont.GET(ExtOrderIn."Sell-to Contact No.") THEN BEGIN
            DelCont.INIT;
            DelCont.VALIDATE("No.", ExtOrderIn."Sell-to Contact No.");
            DelCont."Phone No." := ExtOrderIn."Sell-to Contact No.";
            DelCont."LSC External No." := ExtOrderIn."Order No.";
            DelCont.Type := DelCont.Type::Person;
            //DelCont.SetSkipDefault();
            DelCont.INSERT(TRUE);
        END;
        //IF ExtOrderIn."Address Type" = '4' THEN BEGIN //Home
        //DelCont.Address := ExtOrderIn."Address Description";      //or street no plus street name
        //DelCont.City := ExtOrderIn."Town or City";
        //DelCont."Territory Code" := ExtOrderIn.Territory;
        //DelCont."Country/Region Code" := ExtOrderIn.Country;
        //DelCont."Post Code" := ExtOrderIn."Post Code or Zip";
        //END;
        DelCont.Name := COPYSTR((ExtOrderIn."First Name" + ' ' + ExtOrderIn."Last Name"), 1, MAXSTRLEN(DelCont.Name));
        DelCont."First Name" := ExtOrderIn."First Name";
        DelCont.Surname := ExtOrderIn."Last Name";
        //DelCont."Mobile Phone No." := ExtOrderIn."Mobile Phone No.";
        DelCont."E-Mail" := ExtOrderIn.Mail;

        /*CASE ExtOrderIn."Address Type" OF
            '1':
                DelCont."Next Order Selection" := DelCont."Next Order Selection"::"Delivery Home";
            '3':
                DelCont."Next Order Selection" := DelCont."Next Order Selection"::"Delivery Work";
            '4':
                DelCont."Next Order Selection" := DelCont."Next Order Selection"::"Delivery Other";
            ELSE
                DelCont."Next Order Selection" := DelCont."Next Order Selection"::"Delivery Other";
        END;*/

        //IF ExtOrderIn.Type = '2' THEN
        DelCont."LSC Next Order Selection" := DelCont."LSC Next Order Selection"::Takeout;

        DelCont."LSC Next Order Restaurant" := ExtOrderIn."Store Selected";
        DelCont."LSC Next Order Date" := ExtOrderIn.Date;
        DelCont."LSC Next Order Time" := ExtOrderIn."Time";
        DelCont."LSC Pre-Order Print DateTime" := 0DT;  //if future order
        //DelCont."Next Estimated Prod. Time" := DelOrders."Estimated Prod. Time (Min.)"; Calculate?
        DelCont."LSC Next Delivery Tender" := 0;

        DelCont.MODIFY(TRUE);

        IF NOT DelContAddr.GET(DelCont."Phone No.", DelCont."LSC Next Order Selection" - 1) THEN BEGIN
            DelContAddr.INIT;
            DelContAddr."Phone No." := DelCont."Phone No.";
            DelContAddr."Address Type" := DelCont."LSC Next Order Selection" - 1;
        END;
        DelContAddr."Restaurant No." := ExtOrderIn."Store Selected";
        /*DelContAddr."Street Name" := ExtOrderIn."Street Name";
        DelContAddr."Street No." := ExtOrderIn."Building Number";             //CHECK

        DelContAddr."Building Letter" := ExtOrderIn."Building Letter";
        DelContAddr."Building Name" := ExtOrderIn."Building Name";
        DelContAddr."Country/Region Code" := ExtOrderIn.Country;
        DelContAddr."Country IsoCode" := ExtOrderIn."Country IsoCode";
        DelContAddr.District := ExtOrderIn.District;
        DelContAddr.Intersection := ExtOrderIn.Intersection;
        DelContAddr.Latitude := ExtOrderIn.Latitude;
        DelContAddr.Longitude := ExtOrderIn.Longitude;
        DelContAddr.Region := ExtOrderIn.Region;
        DelContAddr."Room Number" := ExtOrderIn."Room Number";
        DelContAddr."Territory Code" := ExtOrderIn.Territory;

        DelContAddr."Post Code" := ExtOrderIn."Post Code or Zip";
        DelContAddr.City := ExtOrderIn."Town or City";
        DelContAddr.Directions := ExtOrderIn."Delivery Notes";
        IF NOT DelCont."Next Order Rest. Temporary" THEN
            DelContAddr."Restaurant No." := ExtOrderIn."Store No.";

        DelStreet.RESET;
        DeliveryOrderManagement.FindStreetByNumber(DelStreet, DelContAddr."Street Name", DelContAddr."Street No.", DelContAddr."Post Code");
        IF DelStreet.FINDFIRST THEN
            DelContAddr.Grid := DelStreet.Grid;*/

        IF NOT DelContAddr.MODIFY(TRUE) THEN
            DelContAddr.INSERT(TRUE);
        EXIT(DelCont."No.");
    end;

    procedure ValidateServerInventoryTR(pReceipt: Code[20]; pStore: Code[10]; var pError: Boolean; var pErrorText: Text): Boolean
    var
        POSTransLineBK: Record "LSC POS Trans. Line";
        POSTransLine2_l: Record "LSC POS Trans. Line";
        OdataCNN: Codeunit "FSN OData Conexion";
        ItemLogTmp: Record "FSN Inventory Internal Log" temporary;
        ItemUM: Record "Item Unit of Measure";
        XmlRoot: Text;
        WSTable: Record "FSN WebServiceTable";
    begin
        //WVILLALTA13MAY2020-
        CLEAR(ItemLogTmp);
        ItemLogTmp.DELETEALL;
        pError := FALSE;

        POSTransLineBK.RESET;
        POSTransLineBK.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
        POSTransLineBK.SETRANGE(POSTransLineBK."Receipt No.", pReceipt);
        POSTransLineBK.SETRANGE(POSTransLineBK."Entry Type", POSTransLineBK."Entry Type"::Item);
        POSTransLineBK.SETRANGE(POSTransLineBK."Entry Status", POSTransLineBK."Entry Status"::" ");
        IF POSTransLineBK.FIND('-') THEN
            REPEAT
                IF NOT ItemLogTmp.GET(POSTransLineBK.Number) THEN BEGIN
                    ItemLogTmp.INIT;
                    ItemLogTmp."No." := POSTransLineBK.Number;
                    ItemLogTmp."Qty. per UM" := 0;
                    ItemLogTmp.INSERT;
                END;
                IF ItemUM.GET(POSTransLineBK.Number, POSTransLineBK."Unit of Measure") THEN
                    ItemLogTmp."Qty. per UM" += POSTransLineBK.Quantity * ItemUM."Qty. per Unit of Measure"
                ELSE
                    ItemLogTmp."Qty. per UM" += POSTransLineBK.Quantity;

                ItemLogTmp.MODIFY;

            UNTIL POSTransLineBK.NEXT = 0;

        ItemLogTmp.RESET;
        IF NOT ItemLogTmp.FIND('-') THEN BEGIN
            pErrorText := STRSUBSTNO(Text002, pReceipt);
            EXIT(FALSE);
        END;

        XmlRoot := '&lt;ROOT&gt;';
        ItemLogTmp.RESET;
        IF ItemLogTmp.FIND('-') THEN
            REPEAT
                XmlRoot += '&lt;Detail Item="' + ItemLogTmp."No." + '" Quantity="' + FORMAT(ItemLogTmp."Qty. per UM") + '" VariantCode="" StoreNo="' + pStore + '" LocationCode=""/&gt;';
            UNTIL ItemLogTmp.NEXT = 0;
        XmlRoot += '&lt;/ROOT&gt;';

        if WSTable.get(pReceipt) then begin
            if WSTable."WS Request" in ['SEND_POSTRANS_BACKUP', 'SEND_POSTRANS_BACKUP_BC'] then
                pError := RequestInventoryWSEcommerce(pReceipt, ItemLogTmp."No.", '', '', pStore, '', 'FSN_GET_INVENTORY', XmlRoot)
            else
                pError := RequestInventoryWS(ItemLogTmp."No.", '', '', pStore, '', 'FSN_GET_INVENTORY', XmlRoot);
        end else
            pError := RequestInventoryWS(ItemLogTmp."No.", '', '', pStore, '', 'FSN_GET_INVENTORY', XmlRoot);
        IF NOT pError THEN
            pErrorText := Text001;

        EXIT(pError);
    end;

    procedure RequestInventoryWS(ItemNo: Code[20]; VariantNo: Code[10]; StoreNo: Code[10]; StoreNoAcces: Code[10]; TerminalNo: Code[10]; RequestID: Text[30]; XmlInit: Text): Boolean
    var
        pPosMenuLineTmp: Record "LSC POS Menu Line" temporary;
        FSNInventoryMgt: Codeunit "FSN Delivery Inventory Mgt.";
        FuncProfileWebServer: Record "LSC POS Func. Profile Web Serv";
        lResponse: Text;
        lError: Boolean;
    begin
        Clear(lError);
        FuncProfileWebServer.RESET;
        FuncProfileWebServer.SETCURRENTKEY("Profile ID", "Request ID", Priority);
        FuncProfileWebServer.SETRANGE(FuncProfileWebServer."Profile ID", '#FASANI' /*POSSESSION.FunctionalityProfileID()*/);
        FuncProfileWebServer.SETRANGE(FuncProfileWebServer."Request ID", RequestID);
        FuncProfileWebServer.FINDLAST;

        pPosMenuLineTmp.RESET;
        pPosMenuLineTmp.DELETEALL;
        pPosMenuLineTmp.Command := FuncProfileWebServer."Request ID";
        IF RequestID <> '' THEN
            pPosMenuLineTmp.Command := RequestID;
        pPosMenuLineTmp."Post Command" := ItemNo;
        pPosMenuLineTmp."Post Parameter" := StoreNo;
        pPosMenuLineTmp."Store Access" := StoreNoAcces;
        pPosMenuLineTmp."Pos Access" := TerminalNo;
        pPosMenuLineTmp."Current-POSID" := FuncProfileWebServer."Dist. Location";
        //VariantNo select all Variants
        pPosMenuLineTmp.INSERT;
        COMMIT;

        IF FSNInventoryMgt.RUN(pPosMenuLineTmp) THEN; //Control try catch

        IF RequestID = 'FSN_GET_INVENTORY' THEN BEGIN
            lResponse := FSNInventoryMgt.GetResponse(lError);
            IF lResponse = 'OK' THEN
                EXIT(TRUE);

            EXIT(FALSE);
        END;
    end;

    procedure RequestInventoryWSEcommerce(pReceipt: Code[20]; ItemNo: Code[20]; VariantNo: Code[10]; StoreNo: Code[10]; StoreNoAcces: Code[10]; TerminalNo: Code[10]; RequestID: Text[30]; XmlInit: Text): Boolean
    var
        pPosMenuLineTmp: Record "LSC POS Menu Line" temporary;
        FSNInventoryMgt: Codeunit "FSN Delivery Inventory Mgt.";
        FuncProfileWebServer: Record "LSC POS Func. Profile Web Serv";
        lResponse: Text;
        lError: Boolean;
    begin
        Clear(lError);
        FuncProfileWebServer.RESET;
        FuncProfileWebServer.SETCURRENTKEY("Profile ID", "Request ID", Priority);
        FuncProfileWebServer.SETRANGE(FuncProfileWebServer."Profile ID", '#FASANI' /*POSSESSION.FunctionalityProfileID()*/);
        FuncProfileWebServer.SETRANGE(FuncProfileWebServer."Request ID", RequestID);
        FuncProfileWebServer.FINDLAST;

        pPosMenuLineTmp.RESET;
        pPosMenuLineTmp.DELETEALL;
        pPosMenuLineTmp.Command := FuncProfileWebServer."Request ID";
        IF RequestID <> '' THEN
            pPosMenuLineTmp.Command := RequestID;
        pPosMenuLineTmp."Post Command" := ItemNo;
        pPosMenuLineTmp."Post Parameter" := StoreNo;
        pPosMenuLineTmp."Store Access" := StoreNoAcces;
        pPosMenuLineTmp."Pos Access" := TerminalNo;
        pPosMenuLineTmp."Current-POSID" := FuncProfileWebServer."Dist. Location";
        pPosMenuLineTmp."Current-RECEIPT" := pReceipt;
        //VariantNo select all Variants
        pPosMenuLineTmp.INSERT;
        COMMIT;
        IF FSNInventoryMgt.RUN(pPosMenuLineTmp) THEN; //Control try catch

        IF RequestID = 'FSN_GET_INVENTORY' THEN BEGIN
            //IF RequestID = 'FSN_VALIDATEINVENTORY_ECC' THEN BEGIN
            lResponse := FSNInventoryMgt.GetResponse(lError);
            IF lResponse = 'OK' THEN
                EXIT(TRUE);

            EXIT(FALSE);
        END;
    end;

    procedure GetInventoryLookUpServerTR(pParameter: Record "LSC POS Menu Line")
    var
        ErrorExists: Boolean;
        ResponseXml: Text;
    begin
        DistributionLocationl.Get(pParameter."Current-POSID");
        SetLookUpSecurityText(pParameter, DistributionLocationl);
        SetLookUpRequestText(pParameter);
        SRFTXN := pParameter.Command;
        ResponseXml := WSInventoryTR(ErrorExists);
        GLOBALRESPONSE := ResponseXml;
    end;

    procedure WSInventoryTR(var pError: Boolean) ResponseLocal: Text
    var
        IP: Text[150];
        url: Text;
        soapActionUrl: Text;
        sb: DotNet StringBuilder;
        uriObj: DotNet Uri;
        lgRequest: DotNet HttpWebRequest;
        stream: DotNet StreamWriter;
        lgResponse: DotNet HttpWebResponse;
        str: DotNet Stream;
        reader: DotNet XmlTextReader;
        document: DotNet XmlDocument;
        ascii: DotNet Encoding;
        credentials: DotNet CredentialCache;
        xmlnodelist: DotNet XmlNodeList;
        xmlnode: DotNet XmlNode;
        xmlelement: DotNet XmlElement;
        nodos: Integer;
        xmlRequest: Text;
        xmlFinal: File;
        xmlStream: OutStream;
        i: Integer;
        NewLineNo: Integer;
        Index: Integer;
        JSonConvert: DotNet JsonConvert;
        JSonObject: DotNet JObject;
        JSonToken: DotNet JToken;
        String1: Text;
        String2: Text;
        XmlJson: DotNet XmlDocument;
        lTxt0: Label 'Distribution location is not configured';
        lTxt3: Label 'los campos IP,Web Uri y Web Action deben estar configurados en Parametros';
        FSNParameter: Record "FSN Parameter";
    begin
        if (DistributionLocationl."Web Service URI" = '') or
            (DistributionLocationl."Distribution Server" = '')
            then begin
            ResponseLocal := lTxt0;
            pError := true;
        end;

        FSNParameter.Reset();
        FSNParameter.SetRange(FSNParameter.Grupo, 'WS');
        FSNParameter.SetRange(FSNParameter.Codigo, 'INVENTORYEC');
        if FSNParameter.FindFirst() then begin
            if FSNParameter.Activo then begin
                if (FSNParameter.IP = '') or (FSNParameter."Web Uri" = '') or (FSNParameter."Web Action" = '') then begin
                    ResponseLocal := lTxt3;
                    pError := true;
                end else begin
                    IP := FSNParameter.IP;
                    url := FSNParameter."Web Uri";
                    soapActionUrl := FSNParameter."Web Action";
                end;
            end;
        end;

        /*IP := DistributionLocationl."Distribution Server";

        url := DistributionLocationl."Web Service URI";*/
        //soapActionUrl := '"http://tempuri.org/FSN_INVENTORY_TR"';

        xmlRequest := '<?xml version="1.0" encoding="utf-8"?>' +
        '<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
          '<soap:Body>' +
            '<FSN_INVENTORY_TR xmlns="http://tempuri.org/">' +
              '<xsecurity>' + SRFRSECURITY + '</xsecurity>' +
              '<xcommand>' + 'FSN_INVENTORY_TR' + '</xcommand>' +
              '<wsrequest>' + SRFREQUEST + '</wsrequest>' +
            '</FSN_INVENTORY_TR>' +
          '</soap:Body>' +
        '</soap:Envelope>';


        sb := sb.StringBuilder();
        sb.Append(xmlRequest);
        IF xmlFinal.CREATE('C:\Temp\' + 'FSN_INVENTORY_TR' + '-P.xml') THEN BEGIN
            xmlFinal.CREATEOUTSTREAM(xmlStream);
            xmlStream.WRITE(sb.ToString);
            xmlFinal.CLOSE;
        END;
        uriObj := uriObj.Uri(url);
        lgRequest := lgRequest.CreateDefault(uriObj);
        lgRequest.Method := 'POST';
        lgRequest.Host := IP;
        lgRequest.ContentType := 'text/xml; charset=utf-8';
        lgRequest.Headers.Add('SOAPAction', soapActionUrl);
        lgRequest.Timeout := 10000;
        stream := stream.StreamWriter(lgRequest.GetRequestStream(), ascii.UTF8);
        stream.Write(sb.ToString());
        stream.Close();
        lgResponse := lgRequest.GetResponse();
        str := lgResponse.GetResponseStream();
        reader := reader.XmlTextReader(str);
        document := document.XmlDocument();
        document.Load(reader);
        xmlnodelist := document.SelectNodes('//*');
        document.Save('C:\temp\' + 'FSN_INVENTORY_TR' + '-R.xml');
        nodos := 11;

        Index := 0;
        WHILE (Index < xmlnodelist.Count) DO BEGIN
            xmlnode := xmlnodelist.Item(Index);
            IF NOT ISNULL(xmlnode) THEN BEGIN
                CASE xmlnode.Name OF
                    'FSN_INVENTORY_TRResult':
                        ResponseLocal := xmlnode.FirstChild.InnerText;
                END;
            END;
            Index += 1;
        END;
        IF ResponseLocal = '' THEN BEGIN
            ResponseLocal := Text000;
            pError := TRUE
        END;
    end;

    Local procedure SetLookUpSecurityText(pParameter: Record "LSC POS Menu Line"; DistributionLocation: Record "LSC Distribution Location")
    var
        ENCRYPTBYPASSPHRASE: Label 'xRecord2';
    begin
        DistributionLocation.GET(pParameter."Current-POSID");
        SRFRSECURITY := '{' +
          '"user":"' + DistributionLocation."User ID" + '",' +
          '"pss":"' + DistributionLocation.Password + '",' +
          '"dbase":"' + DistributionLocation."Db. Path && Name" + '",' +
          '"dbinstance":"' + DistributionLocation."Db Server Name" + '",' +
          '"locationip":"' + DistributionLocation."Distribution Server" + '",' +
          '"cnnphrase":"' + ENCRYPTBYPASSPHRASE + '",' +
          '"store":"' + pParameter."Store Access" + '"}';
    end;

    local procedure SetLookUpRequestText(pParamters: Record "LSC POS Menu Line")
    begin
        SRFREQUEST := '{' +
                  '"item":"' + pParamters."Post Command" + '",' +
                  '"variant":"' + '' + '",' +
                  '"store":"' + pParamters."Post Parameter" + '"}';
    end;

    procedure SendDeliveryBackup(receiptNo: Code[20])
    var
        menuLine: Record "LSC POS Menu Line";
        postedDeliveryOrder: Record "LSC Posted Delivery Order";
        posTransaction: Record "LSC POS Transaction";
        wsTable: Record "FSN WebServiceTable";
        parameter: Record "FSN Parameter";
        store_tmp, store_tmp2 : Record "LSC Store" temporary;
        store: Record "LSC Store";
        storeLink: Record "FSN Store Link";
        hospFunc: Codeunit "LSC Hospitality Functions";
        delExt: Codeunit "FSN Ecommerce CallCenter Mgt.";
        j, i, prodTimeLength : Integer;
        lat, lon : Decimal;
        position: List of [Text];
        dateTimeIn, timeFrom, timeTo : DateTime;
        ok, error : Boolean;
        errorText: Text;
        openStatus: Option;
        CalType: Option All,"Opening Hours",Receiving,"Rest. Order Taking",,,,Other;
        CalSensor: Codeunit "FSN Call Center SenOrder";
        ECFunc: Codeunit "FSN Ecommerce Functions";
    begin
        //POSSESSION.SetStore('F01');
        //POSSESSION.SetTerminal('PV#28');
        menuLine.Command := 'SEND_ORDERBACKUP';

        j := 0;
        if postedDeliveryOrder.Get(receiptNo) and posTransaction.Get(receiptNo) then begin
            posTransaction.Delete();
            if wsTable.Get(receiptNo) then begin
                wsTable."Status WS" := wsTable."Status WS"::InProcess;
                wsTable.Modify();
                exit;
            end;
        end;

        if parameter.Get('DAF', 'DAF_API') then;

        store.SetFilter("No.", parameter.SetFilterData1 + parameter.SetFilterData2);
        if (parameter.SetFilterData1 <> '') and store.Find('-') then
            repeat
                store_tmp := store;
                if store_tmp.Insert() then;
            until store.Next() = 0;

        if wsTable.Get(receiptNo) and (wsTable."Last Error Text" = '') then begin

            IF wsTable."WS Request" = 'SEND_POSTRANS_BACKUP_BC' then begin
                parameter.reset;
                if parameter.get('PREFACC', wsTable."Store Selected") then
                    if parameter.Activo then
                        exit;
            end;


            menuLine."Current-RECEIPT" := wsTable.LastSlipNo;
            if Evaluate(lat, CopyStr(wsTable."Value Text 1", 1, StrPos(wsTable."Value Text 1", ',') - 1))
            and
            Evaluate(lon, CopyStr(wsTable."Value Text 1", StrPos(wsTable."Value Text 1", ',') + 1, StrLen(wsTable."Value Text 1")))
                then begin
                if wsTable."Order Type" = wsTable."Order Type"::Takeaway then
                    CalType := CalType::"Rest. Order Taking"
                else
                    CalType := CalType::"Opening Hours";
                storeLink.Reset();
                storeLink.SetRange(Type, storeLink.Type::StoreSetup);
                if storeLink.Find('-') then
                    repeat
                        dateTimeIn := CurrentDateTime;
                        ok := CalSensor.FindProductionTime(CalType,
                            storeLink."Parent Code",
                            0,
                            '',
                            dateTimeIn,
                            0,
                            errorText,
                            false,
                            prodTimeLength,
                            timeFrom,
                            timeTo,
                            openStatus
                        );

                        if ok and not store_tmp.Get(storeLink."Parent Code") then begin
                            store_tmp2.Init();
                            store_tmp2."Fraud Sort Field" := GetDistanceGeopraphic(
                                lat,
                                lon,
                                storeLink."Parent Latitude",
                                storeLink."Parent Longitude"
                            );
                            store_tmp2."No." := storeLink."Parent Code";
                            if store_tmp2."Fraud Sort Field" <= 5 then
                                if store_tmp2.Insert() then;
                        end;
                    until storeLink.Next() = 0;

                i := 0;
                Clear(ok);
                store_tmp2.Reset();
                store_tmp2.SetCurrentKey("Fraud Sort Field");
                if store_tmp2.Find('-') then
                    repeat
                        ok := ValidateServerInventoryTR(wsTable.LastSlipNo, store_tmp2."No.", error, errorText);
                        if ok then begin
                            i := 5;
                            wsTable."Store Selected" := store_tmp2."No.";
                        end else
                            i += 1;

                    until (store_tmp2.Next() = 0) or (i >= 5);
                if ok then begin
                    wsTable.Modify();
                    Commit();
                    IF NOT (wsTable."WS Request" IN ['SEND_POSTRANS_BACKUP', 'SEND_POSTRANS_BACKUP_BC']) THEN
                        if delExt.Run(menuLine) then;
                end;
            end;
        end;
    end;


    procedure GetDistanceGeopraphic(lat: Decimal; lon: Decimal; ParentLatitude: Decimal; ParentLongitude: Decimal): Decimal
    var
        pi, dataDiff, _lat, _lon : Decimal;
        math: DotNet MathNet;
    begin
        pi := 3.14159265358979323;

        _lat := (lat - ParentLatitude) * (pi / 180);
        _lon := (lon - ParentLongitude) * (pi / 180);

        lat := lat * (pi / 180);
        ParentLatitude := ParentLatitude * (pi / 180);

        dataDiff := math.Pow(math.Sin(_lat / 2), 2) + math.Cos(lat) * math.Cos(ParentLatitude) * math.Pow(math.Sin(_lon / 2), 2);

        exit(6371 * (2 * math.Atan2(math.Sqrt(dataDiff), math.Sqrt(1 - dataDiff))));
    end;

    local procedure ecommerceFunc(var XMLRequest: Text; var RequestID: Text[50]; var XMLResponse: Text): Text
    var
        ecommerceFunc: Codeunit "FSN Ecommerce Functions";
    begin
        ecommerceFunc.SetRequestGlobals(XMLRequest, RequestID);
        if ecommerceFunc.Run() then
            XMLResponse := ecommerceFunc.GetResponseGlobals()
        else
            XMLResponse := 'ERROR';
        exit(XMLResponse);
    end;

    procedure GetTransSuspList(pParameter: Record "LSC POS Menu Line")
    var
        ValueReceipt: Code[30];
        PosTrans: Record "LSC POS Transaction";
        lText001: Label 'Phone No.';
        POSMenuLine: Record "LSC POS Menu Line";
        CSWebServiceTable: Record "FSN WebServiceTable";
        QueryCSWebServiceConsistency: Query "FSN CSWebServiceTable Status";
    begin

        CLEAR(QueryCSWebServiceConsistency);
        QueryCSWebServiceConsistency.SETRANGE(QueryCSWebServiceConsistency.Date, TODAY - 1, TODAY);
        QueryCSWebServiceConsistency.OPEN;

        WHILE QueryCSWebServiceConsistency.READ() DO
            IF QueryCSWebServiceConsistency.Order_No = '' THEN
                IF PosTrans.GET(QueryCSWebServiceConsistency.LastSlipNo) AND
                  CSWebServiceTable.GET(QueryCSWebServiceConsistency.LastSlipNo) THEN BEGIN
                    CSWebServiceTable."Status WS" := CSWebServiceTable."Status WS"::Pending;
                    CSWebServiceTable.MODIFY;
                    PosTrans."Entry Status" := PosTrans."Entry Status"::Suspended;
                    PosTrans.MODIFY;
                END;
        QueryCSWebServiceConsistency.CLOSE;


        CASE pParameter.Parameter OF
            'ECOMM':
                POSSESSION.SetValue('#KEY1ECOMMTYPE', '1..2')
            ELSE
                POSSESSION.SetValue('#KEY1ECOMMTYPE', '<>1&<>2')
        END;
        POSSetupExtBK.Reset();
        POSSetupExtBK.SetRange("Type", POSSetupExtBK."Type"::CallCenter);
        POSSetupExtBK.SetRange("Line Type", POSSetupExtBK."Line Type"::Parameter);
        POSSetupExtBK.SetRange("Value No.", 'WEBPANEL_LOOKUP');
        if POSSetupExtBK.Find('+') then
            POSTransaction.LookUp(true, 'SUSPEND_PHONE', 'DELIVERY')
        else
            POSTransaction.LookUp(true, POSSetupExtBK."Value Reference No.", 'DELIVERY');
    end;

    procedure GetTransSuspListSelect(pParameter: Record "LSC POS Menu Line")
    var
        ValueReceipt: Code[20];
        Contact_l: Record Contact;
        Store_l: Record "LSC Store";
        DeliveryFunc: Codeunit "LSC Delivery Functions";
    begin
        RetailSetupBK.Get;
        Store_l.Get(RetailSetupBK."Local Store No.");

        ValueReceipt := POSGUI.GetLookupKeyValue('SUSPEND_PHONE');

        IF ValueReceipt = '' THEN
            EXIT;

        IF POSTransactionBK.GET(ValueReceipt) THEN BEGIN
            /*IF (POSTransactionBK."Sell-to Contact No." <> '') THEN*/
            if CSWebServiceTableBK.Get(ValueReceipt) then begin
                CSWebServiceTableBK."Status WS" := CSWebServiceTableBK."Status WS"::InProcess;
                CSWebServiceTableBK.MODIFY;
                CreatePreOrder(CSWebServiceTableBK);
            end
        END ELSE BEGIN
            IF CSWebServiceTableBK.GET(ValueReceipt) THEN BEGIN
                if not Contact_l.Get(CSWebServiceTableBK."Sell-to Contact No.") then begin
                    Contact_l.Init();
                    Contact_l."No." := CSWebServiceTableBK."Sell-to Contact No.";
                    Contact_l.Name := CSWebServiceTableBK."First Name" + ' ' + CSWebServiceTableBK."Last Name";
                    Contact_l.Insert();
                end;
                Contact_l."LSC Next Order Date" := Today;
                Contact_l."LSC Next Delivery Tender" := 0;
                Contact_l."LSC Next Order Selection" := Contact_l."LSC Next Order Selection"::"Delivery Other";
                Contact_l."LSC Next Order Restaurant" := POSTransactionBK."Store No.";
                Contact_l."LSC Next Order Time" := Time;

                DeliveryOrderManagement.UpdateOrder(CSWebServiceTableBK.LastSlipNo, Contact_l, true, DeliveryFunc.CallCenterIsOffline(Store_l), true);
                if not DeliveryOrderBK.Get(CSWebServiceTableBK.LastSlipNo) then
                    exit;
                CSWebServiceTableBK."Status WS" := CSWebServiceTableBK."Status WS"::InProcess;
                CSWebServiceTableBK.MODIFY;
                DeliveryOrderManagement.TakeOrder(POSTransactionBK."Sell-to Contact No.");
            END;
        END;
    end;

    procedure CreatePreOrder(WebTable: Record "FSN WebServiceTable")
    var
        myInt: Integer;
        DelOrder: Record "LSC Delivery Order";
        SalesType: Integer;
        DelOrdManagement: Codeunit "LSC Delivery Order Management";
        DelContOrder: Record Contact;
        DeliveryOrderType: Option Home,Work,Other,Takeout;
        PageDeliveryTakeOrder: Page "FSN Take Order CC";
        DelCustAddr: Record "LSC Delivery Contact Address";
        DelStreet_l: Record "LSC Delivery Street";
        POSTransaction: Record "LSC POS Transaction";
        FSNAlterKey: Integer;
        FSNDeliveryFunct: Codeunit "FSN Delivery Functions Extend";
        SalesTypes: Record "LSC Sales Type";
        Text090: Label 'Ocurrió un error al insertar en la tabla %1. Intentar otra vez.';
        POSLine: Record "LSC POS Trans. Line";
    begin

        IF POSTransaction.GET(WebTable.LastSlipNo) THEN BEGIN
            case WebTable."Order Type" of
                WebTable."Order Type"::FromStoreDelivery:
                    begin
                        case WebTable."Value Text 1" of
                            '0':
                                begin
                                    DeliveryOrderType := DeliveryOrderType::Home;
                                    SalesType := 1;
                                end;
                            '1':
                                begin
                                    DeliveryOrderType := DeliveryOrderType::Work;
                                    SalesType := 2;
                                end;
                            '2':
                                begin
                                    DeliveryOrderType := DeliveryOrderType::Other;
                                    SalesType := 3;
                                end;
                        end;
                    end;
                WebTable."Order Type"::HomeOfficeDelivery:
                    begin
                        DeliveryOrderType := DeliveryOrderType::Work;
                        SalesType := 2;
                    end;
                WebTable."Order Type"::Delivery:
                    begin
                        DeliveryOrderType := DeliveryOrderType::Other;
                        SalesType := 3;
                    end;
                WebTable."Order Type"::FromStoreTakeaway, WebTable."Order Type"::Takeaway:
                    begin
                        DeliveryOrderType := DeliveryOrderType::Takeout;
                        SalesType := 4;
                    end;
            end;


            //ValidateDelCont(WebTable);
            DelCustAddr.Reset();
            if DelCustAddr.Get(WebTable."Sell-to Contact No.", DeliveryOrderType) then begin
                DelStreet_l.Reset();
                DelStreet_l.SetRange("Street Name", DelCustAddr."Street Name");//CopyStr(Rec.Address, 3, 30)
                DelStreet_l.SetRange("Number from", 1);
                if DelCustAddr."Post Code" <> '' then
                    DelStreet_l.SetRange("Post Code", DelCustAddr."Post Code");
                if DelStreet_l.FindFirst() then begin
                    DelStreet_l.CalcFields(City);
                    FSNAlterKey := DelStreet_l."FSN Alter Key";

                    IF DelCustAddr."Street Name" <> DelStreet_l."Street Name" THEN
                        DelCustAddr."Street Name" := DelStreet_l."Street Name";

                    IF DelCustAddr."Post Code" <> DelStreet_l."Post Code" THEN
                        DelCustAddr."Post Code" := DelStreet_l."Post Code";

                    IF DelCustAddr.City <> DelStreet_l.City THEN
                        DelCustAddr.City := DelStreet_l.City;


                    IF DelCustAddr."Grid Code" <> DelStreet_l."Grid Code" THEN
                        DelCustAddr."Grid Code" := DelStreet_l."Grid Code";

                    DelCustAddr.Modify();
                end else
                    clear(FSNAlterKey);

                if not DelContOrder.get(WebTable."Sell-to Contact No.") then BEGIN
                    DelContOrder.Init();
                    DelContOrder."No." := WebTable."Sell-to Contact No.";
                end;
                DelContOrder."LSC Next Order Date" := Today;
                if DelContOrder.Name = '' Then
                    DelContOrder.Name := CopyStr(WebTable."First Name" + ' ' + WebTable."Last Name", 1, 100);
                DelContOrder."LSC Next Order Time" := Time;
                DelContOrder."LSC Pre-Order Print DateTime" := 0DT;
                DelContOrder."LSC Next Order Selection" := DeliveryOrderType;
                if WebTable."Store Selected" <> '' then
                    DelContOrder."LSC Next Order Restaurant" := Copystr(WebTable."Store Selected", 1, 3)
                else
                    DelContOrder."LSC Next Order Restaurant" := DelCustAddr."Restaurant No.";
                if not DelContOrder.Insert(true) then
                    DelContOrder.Modify(true);


                POSSESSION.SetValue('VALSECC', 'True');
                if not DelOrdManagement.UpdateOrder(WebTable.LastSlipNo, DelContOrder, true, true, true) then begin
                    POSSESSION.SetTempStoreTerminal('', '', DelOrder."Sales Type");
                    Message(StrSubstNo(Text090, DelOrder.TableCaption));
                    exit;
                end;
                IF DelOrder.Get(WebTable.LastSlipNo) then;
                DelOrder.Validate("Order Type Option", SalesType);

                if SalesTypes.Get(DelOrder."Sales Type") then begin
                    if SalesTypes."VAT Bus. Posting Group" <> '' then
                        POSTransaction."VAT Bus.Posting Group" := SalesTypes."VAT Bus. Posting Group";
                    if SalesTypes."Price Group" <> '' then
                        POSTransaction."Price Group Code" := SalesTypes."Price Group";
                    POSTransaction."Sales Type" := SalesTypes.Code;
                    //POSTransaction.Modify(true);
                end;
                DelOrder.Reset();
                IF DelOrder.Get(WebTable.LastSlipNo) then begin
                    DelOrder.Validate("Order Type Option", SalesType);
                    DelOrder.Name := CopyStr(WebTable."First Name" + ' ' + WebTable."Last Name", 1, 100);
                    DelOrder.Address := '1' + ' ' + DelCustAddr."Street Name";
                    DelOrder."Address 2" := DelCustAddr."Address 2";
                    DelOrder.City := DelStreet_l.City;
                    DelOrder."Created at Call Center" := 'F20';
                    DelOrder."Post Code" := DelCustAddr."Post Code";
                    DelOrder.Directions := DelCustAddr.Directions;
                    DelOrder."FSN Directions" := DelCustAddr."FSN Direction";
                    DelOrder."Grid Code" := DelCustAddr."Grid Code";
                    DelOrder."Sales Type" := POSTransaction."Sales Type";
                    DelOrder."FSN Alter Key" := FSNAlterKey;
                    DelOrder."FSN Street Name" := DelCustAddr."Street Name";
                    DelOrder.Modify();
                    Commit();
                end;
            END;

            IF WebTable."WS Request" IN ['SEND_POSTRANS_BACKUP', 'SEND_POSTRANS_BACKUP_BC'] THEN begin
                IF WebTable."WS Request" <> '' THEN
                    FSNDeliveryFunct.ChangeStore(WebTable.LastSlipNo, WebTable."Store Selected", 1);
                DelOrder.Reset();
                if DelOrder.Get(WebTable.LastSlipNo) then;
            end else
                FSNDeliveryFunct.ChangeStore(DelOrder."Order No.", DelOrder."Restaurant No.", 1);
            POSLine.Reset();
            POSLine.SetRange("Receipt No.", DelOrder."Order No.");
            POSLine.SetRange("Entry Status", POSLine."Entry Status"::" ");
            POSLine.SetRange(POSLine."Entry Type", POSLine."Entry Type"::Payment);
            if POSLine.find('-') then
                repeat
                    if POSLine."FSN Additional Action" = POSLine."FSN Additional Action"::ConfirmPayment then begin
                        POSLine."FSN Additional Action" := POSLine."FSN Additional Action"::Nothing;
                        POSLine.Modify();
                    end
                until POSLine.Next() = 0;

            POSSESSION.SetValue('CURRORDER', WebTable.LastSlipNo);
            POSSESSION.SetValue('CURRORDER2', WebTable.LastSlipNo);

            PageDeliveryTakeOrder.VisiblePosTransLine(true);
            PageDeliveryTakeOrder.SETGLOBALVALUE(DelOrder);
            PageDeliveryTakeOrder.RUN;
        END;
    end;

    procedure StretNo(wsTable: Record "FSN WebServiceTable")
    var
        myInt: Integer;
        storeLink: record "FSN Store Link";
        lat: Decimal;
        lon: Decimal;
        storeLink_tmp2: record "FSN Store Link" temporary;
        StoreLink2: Record "FSN Store Link";
        DelCont: Record "LSC Delivery Contact Address";
        km: Decimal;
        Delstret: Record "LSC Delivery Street";
        km2: Decimal;
        store: Record "LSC Store";
        store_tmp, store_tmp2 : Record "LSC Store" temporary;
        OrderType: Option Home,Work,Other,Takeout;
        DelContac: Record Contact;
    begin
        if Evaluate(lat, CopyStr(wsTable."Value Text 1", 1, StrPos(wsTable."Value Text 1", ',') - 1))
            and
            Evaluate(lon, CopyStr(wsTable."Value Text 1", StrPos(wsTable."Value Text 1", ',') + 1, StrLen(wsTable."Value Text 1")))
                then begin


            storeLink.Reset();
            storeLink.SetRange(Type, storeLink.Type::StoreSetup);
            if storeLink.Find('-') then
                repeat
                    store_tmp2.Init();
                    store_tmp2."Fraud Sort Field" := GetDistanceGeopraphic(
                        lat,
                        lon,
                        storeLink."Parent Latitude",
                        storeLink."Parent Longitude"
                    );
                    store_tmp2."No." := storeLink."Parent Code";
                    if store_tmp2."Fraud Sort Field" <= 5 then
                        if store_tmp2.Insert() then;
                until storeLink.Next() = 0;
            store_tmp2.Reset();
            store_tmp2.SetCurrentKey("Fraud Sort Field");
            if store_tmp2.Find('-') then;



            StoreLink2.Reset();
            StoreLink2.SetRange(Type, StoreLink2.Type::StreetAlterKey);
            StoreLink2.SetRange("Link Type", StoreLink2."Link Type"::DeliveryStore);
            StoreLink2.SetRange("Store No.", store_tmp2."No.");
            StoreLink2.SetFilter("Km Distance Driver", '<>%1', 0);
            StoreLink2.SetFilter("Km Between Points", '<=%1', store_tmp2."Fraud Sort Field");
            if StoreLink2.Find('-') then begin
                repeat
                    IF CopyStr(StoreLink2."Parent Code Name", 1, 6) <> 'FASANI' then begin
                        store_tmp.Init();
                        store_tmp."Fraud Sort Field" := GetDistanceGeopraphic(
                                                        lat,
                            lon,
                            StoreLink2."Parent Latitude",
                            StoreLink2."Parent Longitude"
                        );
                        store_tmp."No." := StoreLink2."Parent Code";
                        if store_tmp."Fraud Sort Field" <= StoreLink2."Km Between Points" then
                            if store_tmp.Insert() then;
                    end;
                until storeLink2.Next() = 0;

                store_tmp.Reset();
                store_tmp.SetCurrentKey("Fraud Sort Field");
                if store_tmp.Find('-') then begin
                    Delstret.Reset();
                    Delstret.SetRange("FSN Alter Key Text", store_tmp."No.");
                    if Delstret.FindFirst() then begin
                        DelCont.Reset();
                        if wsTable."Order Type" = wsTable."Order Type"::Delivery then
                            DelCont.SetRange("Address Type", DelCont."Address Type"::Home);
                        if wsTable."Order Type" = wsTable."Order Type"::Takeaway then
                            DelCont.SetRange("Address Type", DelCont."Address Type"::Takeout);
                        DelCont.SetRange("Phone No.", wsTable."Sell-to Contact No.");
                        if DelCont.FindFirst() then begin
                            DelCont."Street Name" := Delstret."Street Name";
                            DelCont."Post Code" := Delstret."Post Code";
                            DelCont."Restaurant No." := Delstret."Restaurant No.";
                            DelContac.Reset();
                            if DelContac.Get(wsTable."Sell-to Contact No.") then begin
                                DelContac.Name := wsTable."First Name" + ' ' + wsTable."Last Name";
                                DelContac."Search Name" := wsTable."First Name";
                                if not DelContac.Insert() then
                                    DelContac.Modify(true)
                            end;
                            DelCont.Modify();
                        end;
                    end;
                end;
            end;
        end;
    end;


    procedure CreateWSTable(pCode: Code[20])
    var
        fsnWSTable: Record "FSN WebServiceTable";
    begin
        //Test Function
        RetailSetupBK.Get();
        if POSTransactionBK.Get(pCode) then begin
            if not fsnWSTable.Get(pCode) then begin
                POSTransactionBK."Sell-to Contact No." := '72948098';
                POSTransactionBK.Modify();

                fsnWSTable.Init();
                fsnWSTable.LastSlipNo := POSTransactionBK."Receipt No.";
                fsnWSTable.Store := POSTransactionBK."Store No.";
                fsnWSTable.Terminal := POSTransactionBK."POS Terminal No.";
                fsnWSTable."Status WS" := fsnWSTable."Status WS"::Pending;
                fsnWSTable."Order No." := '9999';
                fsnWSTable."Distribution Location" := RetailSetupBK."Distribution Location";
                fsnWSTable.Date := Today;
                fsnWSTable.Time := Time;
                fsnWSTable."Sell-to Contact No." := POSTransactionBK."Sell-to Contact No.";
                fsnWSTable."Order Type" := fsnWSTable."Order Type"::Delivery;
                fsnWSTable."Store Selected" := 'F08';
                fsnWSTable."First Name" := 'William Edgardo';
                fsnWSTable."Last Name" := 'Villalta Alfaro';
                fsnWSTable."Document Personal" := '02336598-7';
                fsnWSTable."Document Type" := fsnWSTable."Document Type"::DUI;

                POSTransactionBK.CalcFields("Gross Amount");
                fsnWSTable.Amount := POSTransactionBK."Gross Amount";
                fsnWSTable.Insert();
            end;
        end;
    end;


    procedure ValidateDelCont(WS: Record "FSN WebServiceTable")
    var
        DelContact: Record "LSC Delivery Contact Address";
        OrderType: Option Home,Work,Other,Takeout;
    begin
        if WS."Order Type" = ws."Order Type"::Delivery then
            OrderType := OrderType::Home;
        if WS."Order Type" = ws."Order Type"::Takeaway then
            OrderType := OrderType::Takeout;
        if DelContact.Get(ws."Sell-to Contact No.", OrderType) then begin
            if DelContact."Street Name" = '' then
                StretNo(WS);
        end;
    end;

    procedure GetResponse(var pError: Boolean) pResponse: Text
    begin
        pError := GlobalError;
        exit(GLOBALRESPONSE);
    end;

    var
        DeliveryOrderBK: Record "LSC Delivery Order";
        DelContactAddressBK: Record "LSC Delivery Contact Address";
        DeliveryStreetBK: Record "LSC Delivery Street";
        POSTransactionBK: Record "LSC POS Transaction";
        POSTransLineBK: Record "LSC POS Trans. Line";
        HospitalitySetupBK: Record "LSC Hospitality Setup";
        CSWebServiceTableBK: Record "FSN WebServiceTable";
        POSSetupExtBK: Record "FSN POS Setup Extend";
        ContacBK: Record Contact;
        RetailSetupBK: Record "LSC Retail Setup";
        CCPOSTermBK: Record "LSC CC POS Term. Assignm."; //"Call Cent. POS Term. Assignm.";
        DeliveryOrderManagement: Codeunit "LSC Delivery Order Management";
        POSSESSION: Codeunit "LSC POS Session";
        POSTransaction: Codeunit "LSC POS Transaction";
        BOUTIL: Codeunit "LSC BO Utils";
        POSGUI: Codeunit "LSC POS GUI";
        FSNEcommFunction: Codeunit "FSN Ecommerce Functions";
        Text000: Label 'Generic error. unknown';
        Text001: Label 'Response WS is not sucessfull.';
        Text002: Label 'Order %1 not exists or havent items';
        SRFRSECURITY: Text;
        SRFTXN: Text;
        SRFREQUEST: Text;
        GLOBALRESPONSE: Text;
        GlobalError: Boolean;
        DistributionLocationl: Record "LSC Distribution Location";
        DeliveryINV: Codeunit "FSN Delivery Inventory Mgt.";

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"FSN Utility", 'OnInvokeGlobalChannelEvent', '', true, true)]
    local procedure "FSN Utility_OnInvokeGlobalChannelEvent"
      (
          var XMLRequest: Text;
          var XMLResponse: Text;
          var RequestID: Text[50];
          var POSMenuLine: Record "LSC POS Menu Line";
          var Processed: Boolean;
          var MsgResult: Text
      )
    begin
        if RequestID in ['SEND_POSTRANS_BACKUP', 'SEND_POSTRANS_BACKUP_BC'] then begin

            FSNEcommFunction.ClearGlobals();
            FSNEcommFunction.SetCommandGlobals('SENDORDER', POSMenuLine."Current-RECEIPT");
            IF FSNEcommFunction.RUN() THEN;
            FSNEcommFunction.ClearGlobals();
            IF POSMenuLine.Parameter IN ['DELIVERY'] THEN BEGIN
                IF POSTransactionBK.GET(POSMenuLine."Current-RECEIPT") AND
                  NOT (DeliveryOrderBK.GET(POSMenuLine."Current-RECEIPT")) THEN
                    Processed := false
                else
                    Processed := true;
            END;
        end;

        if RequestID in ['FSN_ECOMM_ITEMCROSS_X', 'FSN_ECOMM_CHECK_DELSTORE_X', 'FSN_ECOMM_CHECK_DELTAKEAWAY_X'] then begin
            XMLResponse := ecommerceFunc(XMLRequest, RequestID, XMLResponse);
        end;
    end;
}
