page 50058 "FSN Take Order CC"
{
    Caption = 'FSN Pedido CC';
    //PromotedActionCategories = 'New,Process,Reports,Comments,Process Call,Pricing,Category7_caption,Category8_caption,Category9_caption,Category10_caption';
    PageType = Card;
    UsageCategory = Administration;
    ApplicationArea = All;
    RefreshOnActivate = true;
    SourceTable = "LSC Delivery Order";
    SourceTableTemporary = true;
    DeleteAllowed = false;
    SaveValues = true;
    InsertAllowed = false;
    //InsertAllowed = false;
    layout
    {
        area(content)
        {
            group(General)
            {
                Caption = 'General';
                field(ChannelV; ChannelV)
                {
                    Caption = 'Canal de ventas';
                    Editable = ProcesarPedido;
                    ShowMandatory = true;
                    trigger OnLookup(var Text: Text): Boolean

                    var
                        ChannelPage: page "FSN Channel Links type";
                        FSNCallCenterControl: Codeunit "FSN CallCenter Controller";
                        InputRequire: Boolean;
                        StepProcess: Option Input,ByStaff,All;
                        POSGUI: Codeunit "LSC POS GUI";
                        lTxt1: Label 'No puedo cargar el pedido';
                        StaffID: Code[20];
                        GrupoSalesMemberTmp: Record "LSC Cmsn Salesp. Grp Member" temporary;
                        GrupoSalesMember: Record "LSC Cmsn Salesp. Grp Member";
                        POSInfocodeTmpAll: Record "LSC Infocode" temporary;
                        POSInfocodeTmpStaff: Record "LSC Infocode" temporary;
                        CodStaff: Code[20];
                        ShowAll: Boolean;
                        ComissionSalesGroup: Record "LSC Cmsn Salesperson Group";
                        InputReq: Boolean;
                        Channels: Record "FSN POS Setup Extend";
                        PermissionChannels: Record "FSN POS Setup Extend";
                        TEXTO: Text;
                        SalesChan: Record "FSN Sales Channel";
                    begin
                        POSInfocodeTmpAll.Reset();
                        if POSInfocodeTmpAll.Find('-') then
                            exit;
                        POSInfocodeTmpStaff.Reset();
                        if POSInfocodeTmpStaff.Find('-') then
                            exit;
                        CLEAR(GrupoSalesMemberTmp);
                        GrupoSalesMemberTmp.RESET;
                        GrupoSalesMemberTmp.DELETEALL;

                        GrupoSalesMember.RESET;
                        GrupoSalesMember.SETRANGE(GrupoSalesMember."No.", POSSESSION.StaffID());
                        IF GrupoSalesMember.FIND('-') THEN
                            REPEAT
                                GrupoSalesMemberTmp.INIT;
                                GrupoSalesMemberTmp := GrupoSalesMember;
                                IF GrupoSalesMemberTmp.INSERT THEN;
                            UNTIL GrupoSalesMember.NEXT = 0;

                        IF NOT ShowAll THEN
                            IF GrupoSalesMemberTmp.FIND('-') THEN
                                REPEAT
                                    IF ComissionSalesGroup.GET(GrupoSalesMemberTmp."Group Code") THEN BEGIN
                                        IF NOT InputReq AND ComissionSalesGroup."FSN Require Input" THEN
                                            InputReq := ComissionSalesGroup."FSN Require Input";

                                        PermissionChannels.RESET;
                                        PermissionChannels.SETCURRENTKEY("Value No.", "Store No.", "From Date", "To Date");
                                        PermissionChannels.SETRANGE(PermissionChannels.Type, PermissionChannels.Type::CallCenter);
                                        PermissionChannels.SETRANGE(PermissionChannels."Line Type", PermissionChannels."Line Type"::Parameter);
                                        PermissionChannels.SETRANGE(PermissionChannels."Value No.", 'CHANNELGROUP');
                                        PermissionChannels.SETRANGE(PermissionChannels."Store No.", GrupoSalesMemberTmp."Group Code");
                                        IF PermissionChannels.FIND('-') THEN
                                            REPEAT
                                                Channels.RESET;
                                                Channels.SETCURRENTKEY(Type, "Line Type", "From Date", "Value No.", "Line No.", "Store No.");
                                                Channels.SETRANGE(Channels.Type, Channels.Type::CallCenter);
                                                Channels.SETRANGE(Channels."Line Type", Channels."Line Type"::Parameter);
                                                Channels.SETRANGE(Channels."From Date", 0D);
                                                Channels.SETRANGE(Channels."Value No.", 'CHANNELTYPE');
                                                Channels.SETRANGE(Channels."Store No.", '');
                                                Channels.SETRANGE(Channels."Line No.", PermissionChannels."Line No.");
                                                IF Channels.FIND('-') THEN
                                                    REPEAT
                                                        IF NOT POSInfocodeTmpStaff.GET(FORMAT(Channels."Line No.")) THEN BEGIN
                                                            POSInfocodeTmpStaff.INIT;
                                                            POSInfocodeTmpStaff.Code := FORMAT(Channels."Line No.");
                                                            POSInfocodeTmpStaff.Description := Channels."Data Extra 1";
                                                            POSInfocodeTmpStaff."Input Required" := ComissionSalesGroup."FSN Require Input";
                                                            POSInfocodeTmpStaff.INSERT;
                                                        END;
                                                    UNTIL Channels.NEXT = 0;
                                            UNTIL PermissionChannels.NEXT = 0;
                                    END;
                                UNTIL GrupoSalesMemberTmp.NEXT = 0;
                        if GrupoSalesMemberTmp."Group Code" <> '' then begin
                            ChannelPage.SetTableView(PermissionChannels);
                            ChannelPage.LookupMode := true;
                            if ChannelPage.RunModal() = Action::LookupOK then
                                if SalesChan.Get(POSSESSION.GetValue('CURRORDER')) then begin
                                    ChannelV := SalesChan.SalesChannel;
                                end;
                        end else
                            Message('No se encuentra asignado/a a canal de ventas');
                    end;
                }
                field("Tienda: "; Restaurante)
                {
                    Editable = true;
                    TableRelation = "LSC Store" WHERE("Auto. Calculate Statement" = CONST(true));
                    trigger OnValidate()
                    var
                        ActiveLocation: Record Location;
                        Text010: Label 'Tienda %1, %2';
                        Text011: Label 'Debe confirmar medio de pago';
                        Text016: label 'no puede ser seleccionada';
                        Text012: Label 'No puede cambiar sala en pedido enviado/cancelado en sala';
                        ErrorSales: Label 'No puede cambiar sala con pedido en estado %1';
                        DelOrdrFilt: Record "LSC Delivery Order";
                        RangesTxt: Text[250];
                        IsOpen: Boolean;
                        DayNameEs: Text[30];
                    begin
                        if Globals."Call Cent. Web Service Status" in [Globals."Call Cent. Web Service Status"::"New-Sent",
                        Globals."Call Cent. Web Service Status"::"Changed-Sent"] then begin
                            message(StrSubstNo(ErrorSales, Globals."Call Cent. Web Service Status"));
                            Restaurante := Globals."Restaurant No.";
                            exit;
                        end;

                        UpdateRestaurante(Restaurante);

                        if DelOrdrFilt.Get(Globals."Order No.") then
                            SETGLOBALVALUE(DelOrdrFilt);

                        // Validación de apertura tras cambiar la tienda
                        if (Restaurante <> '') and (Restaurante <> 'F20') then begin
                            IsOpen := IsStoreOpenAt(Restaurante, DateOrder, TimeOrder, RangesTxt);
                            if not IsOpen then
                                Message('El restaurante %1 no está abierto en %2.\Seleccione otra tienda o cambie la hora del pedido.', Restaurante, Format(TimeOrder));
                        end;
                    end;
                }

                field("Hora: "; TimeOrder)
                {
                    Editable = true;

                    trigger OnValidate()
                    var
                        errortext: text;
                        DelContT: Record Contact temporary;
                        DelOrdrFilt: Record "LSC Delivery Order";
                    begin
                        // GUARDAR PRIMERO en POSSESSION para asegurar persistencia
                        // Guardar hora como formato estándar
                        POSSESSION.SetValue('DEL-PickupTime', Format(TimeOrder));
                        Commit();  // COMMIT INMEDIATO para asegurar persistencia

                        errortext := '';
                        Clear(DelContT);
                        DelContT.DeleteAll();
                        if DelContTEMP.get(PhoneNo) then begin
                            DelContT.Init();
                            DelContT := DelContTEMP;
                            DelContT."LSC Next Order Time" := TimeOrder;
                            DelContT."LSC Pre-Order Print DateTime" := CreateDateTime(DateOrder, TimeOrder);
                            DelContT."LSC Next Order Restaurant" := Restaurante;
                            DelContT.insert();
                            // Suprimir mensajes internos; se valida sin mostrar detalles
                            ValidateTimeOnRestChange(DelContT, errortext, true);
                            if errortext = '' then begin
                                DelContTEMP."LSC Next Order Time" := TimeOrder;
                                DelContTEMP."LSC Pre-Order Print DateTime" := CreateDateTime(DateOrder, TimeOrder);
                                DelContTEMP.Modify();
                                Commit();
                                DelOrdManagement.UpdateOrder(Globals."Order No.", DelContTEMP, true, true, false);

                                // ACTUALIZAR Globals directamente con el nuevo valor para mantener en memoria
                                if Globals."Order No." <> '' then begin
                                    Globals."Contact Pickup Time" := TimeOrder;
                                end;
                            end;

                            if DelOrdrFilt.Get(Globals."Order No.") then begin
                                DelOrdrFilt."Contact Pickup Time" := TimeOrder;
                                DelOrdrFilt."Pre-Order Print DateTime" := CreateDateTime(DateOrder, TimeOrder);
                                DelOrdrFilt.Modify();
                                Commit();
                                SETGLOBALVALUE(DelOrdrFilt);
                            end;
                        end;

                        // Validación adicional contra LSC Retail Calendar Line (horarios por tienda y día)
                        if (Restaurante <> '') and (Restaurante <> 'F20') then begin
                            IsOpen := IsStoreOpenAt(Restaurante, DateOrder, TimeOrder, RangesTxt);
                            if not IsOpen then
                                Message('El restaurante %1 no está abierto en %2.\Seleccione otra tienda o cambie la hora del pedido.', Restaurante, Format(TimeOrder));
                        end;
                    end;
                }

                field("Fecha: "; DateOrder)
                {
                    Editable = true;

                    trigger OnValidate()
                    var
                        errortext: text;
                        DelContT: Record Contact temporary;
                        DelOrdrFilt: Record "LSC Delivery Order";
                        RangesTxt: Text[250];
                        IsOpen: Boolean;
                        DayNameEs: Text[30];
                    begin
                        // GUARDAR PRIMERO en POSSESSION para asegurar persistencia
                        POSSESSION.SetValue('DEL-PickupDate', format(DateOrder));
                        Commit();  // COMMIT INMEDIATO para asegurar persistencia

                        errortext := '';
                        Clear(DelContT);
                        DelContT.DeleteAll();
                        if DelContTEMP.get(PhoneNo) then begin
                            DelContT.Init();
                            DelContT := DelContTEMP;
                            DelContT."LSC Next Order Date" := DateOrder;
                            DelContT."LSC Pre-Order Print DateTime" := CreateDateTime(DateOrder, TimeOrder);
                            DelContT."LSC Next Order Restaurant" := Restaurante;
                            DelContT.insert();
                            // Suprimir mensajes internos; se valida sin mostrar detalles
                            ValidateTimeOnRestChange(DelContT, errortext, true);
                            if errortext = '' then begin
                                DelContTEMP."LSC Next Order Date" := DateOrder;
                                DelContTEMP."LSC Pre-Order Print DateTime" := CreateDateTime(DateOrder, TimeOrder);
                                DelContTEMP.Modify();
                                Commit();
                                DelOrdManagement.UpdateOrder(Globals."Order No.", DelContTEMP, true, true, false);

                                // ACTUALIZAR Globals directamente con el nuevo valor para mantener en memoria
                                if Globals."Order No." <> '' then begin
                                    Globals."Order Date" := DateOrder;
                                end;
                            end;

                            if DelOrdrFilt.Get(POSSESSION.GetValue('CURRORDER')) then begin
                                DelOrdrFilt."Order Date" := DateOrder;
                                DelOrdrFilt."Pre-Order Print DateTime" := CreateDateTime(DateOrder, TimeOrder);
                                DelOrdrFilt.Modify();
                                Commit();
                                SETGLOBALVALUE(DelOrdrFilt);
                            end;
                        end;

                        // Validación adicional contra LSC Retail Calendar Line al cambiar la fecha
                        if (Restaurante <> '') and (Restaurante <> 'F20') then begin
                            IsOpen := IsStoreOpenAt(Restaurante, DateOrder, TimeOrder, RangesTxt);
                            if not IsOpen then
                                Message('El restaurante %1 no está abierto en %2.\Seleccione otra tienda o cambie la hora del pedido.', Restaurante, Format(TimeOrder));
                        end;
                    end;
                }
                field("Pedido: "; POSSESSION.GetValue('CURRORDER'))
                {
                    Editable = false;
                    Style = Strong;
                    StyleExpr = 'StrongAccent';
                }

                field("Estado: "; Estatus)
                {
                    Editable = false;
                    //Style = Strong;
                    //Style = Attention;
                    //Style = Favorable;
                    StyleExpr = StyleStatusText;
                    //StyleExpr = true;

                }

                field("TOTAL.: "; '$' + format(DELAmount))
                {
                    Editable = false;
                    Style = Strong;
                }
                field("TOTAL C/DESC.: "; '$' + Format(DELDiscount))
                {
                    Editable = false;
                    Style = Strong;
                }

                field("PAGO.: "; '$' + format(DELPago))
                {
                    Editable = false;
                    Style = Strong;
                }
                field("Balance.: "; '$' + Format(DELBalance))
                {
                    Editable = false;
                    Style = Strong;
                }
                field(ECotizacion; Cotizacion)
                {
                    Caption = 'Cotizacion';
                    Editable = CotizVisible;

                    trigger OnValidate()
                    var
                        myInt: Integer;
                        Quotation: Codeunit "FSN Quotation";
                    begin
                        POSSESSION.SetValue('CURRORDER', Globals."Order No.");
                        Cotizacion := DelChr(Cotizacion, '=', ' ');
                        Quotation.SendQuotation(true, Cotizacion)
                    end;
                }
            }

            group("DOMICILIO Y PARA LLEVAR")
            {
                Caption = 'Domicilio y Para Llevar.';
                grid(t)
                {
                    group(a)
                    {
                        Caption = '';

                        field(Domicilio; DomicilioTake)
                        {
                            Caption = 'Domicilio';
                            OptionCaption = 'CASA,TRABAJO,OTROS,PARA LLEVAR';
                            Editable = True;

                            trigger OnValidate()
                            var
                                DelCustAddr: Record "LSC Delivery Contact Address";
                                errorText: Text;
                                DelOrdrFilt: Record "LSC Delivery Order";
                            begin
                                FilterAddresPage(DomicilioTake);//28981
                                UpdateAdressDelOrder();
                                if POSSESSION.GetValue('CURRORDER') <> '' then begin
                                    if (Globals."Order No." = POSSESSION.GetValue('CURRORDER')) and not
                                        (Globals."General Status" = Globals."General Status"::ERROR) then begin
                                        if not (Restaurante in ['', 'F20']) then begin//28981
                                            FSNDeliveryFunct.ChangeStore(Globals."Order No.", Restaurante, 1);
                                            IF DelContTEMP.get(PhoneNo) THEN;
                                            // Suprimir mensajes internos; usaremos el pop-up de rangos si aplica
                                            ValidateTimeOnRestChange(DelContTEMP, errorText, true);

                                            if DelOrdrFilt.Get(POSSESSION.GetValue('CURRORDER')) then
                                                SETGLOBALVALUE(DelOrdrFilt);
                                        end ELSE
                                            Restaurante := '';
                                    end;
                                end;
                            end;

                        }
                        field("No Telef."; PhoneNo)
                        {
                            Caption = 'No Telef :.';
                            ApplicationArea = All;
                            Editable = false;

                            trigger OnValidate()
                            var
                            begin
                                Globals."Phone No." := PhoneNo;
                                Globals.Modify();
                                Commit();
                            end;

                        }

                        field(Nombre; NameV)
                        {
                            Caption = 'Nombre :.';
                            ApplicationArea = All;
                            Editable = true;

                            trigger OnValidate()
                            var
                            begin
                                IF POSSESSION.GetValue('CURRORDER') <> '' then begin
                                    Globals.RESET;
                                    IF Globals.Get(POSSESSION.GetValue('CURRORDER')) THEN BEGIN
                                        Globals.Name := UpperCase(NameV);
                                        Globals.Modify();
                                        Commit();
                                    END;
                                end;
                                if DelContTEMP.get(PhoneNo) then begin
                                    DelContTEMP.Name := NameV;
                                    DelContTEMP.Modify();
                                    Commit();
                                end;
                            end;
                        }
                        field("Ciudad"; Address2V)
                        {
                            Caption = 'Ciudad :.';
                            ApplicationArea = All;
                            Editable = false;

                            trigger OnValidate()
                            var
                            begin

                            end;

                        }
                    }
                }
                grid(u)
                {
                    group(b)
                    {
                        Caption = '';
                        field("Colonia/Calle"; AddressV)
                        {
                            Caption = 'Colonia/Calle :.';
                            ApplicationArea = All;
                            Editable = true;
                            TableRelation = "LSC Delivery Street";
                            trigger OnLookup(var Text: Text): Boolean
                            var
                                myInt: Integer;
                                delS: Record "LSC Delivery Street";
                                CalleReparto: Page "FSN Calle Reparto";
                                FirstStore: Code[10];
                            begin
                                CalleReparto.LookupMode := true;
                                if CalleReparto.RunModal() = Action::LookupOK then begin
                                    CalleReparto.GetRecord(delS);
                                    if delS."Street Name" <> '' then begin
                                        AddressV := delS."Street Name";
                                        IF AddressV <> '' then begin
                                            if POSSESSION.GetValue('CURRORDER') <> '' then begin
                                                if not (Globals."General Status" = Globals."General Status"::ERROR) then
                                                    if not (Globals."Call Cent. Web Service Status" in [Globals."Call Cent. Web Service Status"::"New-Sent",
                                                    Globals."Call Cent. Web Service Status"::"Changed-Sent", Globals."Call Cent. Web Service Status"::"Cancelled-Sent"]) then
                                                        IF DomicilioTake <> DelCustAddr."Address Type"::Takeout then begin
                                                            StoreEditedManually := false;
                                                            SetManualFlagForType(DomicilioTake, false);
                                                            FirstStore := GetFirstSuggestedStore(delS."FSN Alter Key");
                                                            if FirstStore <> '' then
                                                                Restaurante := FirstStore
                                                            else
                                                                Restaurante := delS."Restaurant No.";
                                                        end;


                                            end else begin
                                                IF DomicilioTake <> DelCustAddr."Address Type"::Takeout then begin
                                                    StoreEditedManually := false;
                                                    SetManualFlagForType(DomicilioTake, false);
                                                    FirstStore := GetFirstSuggestedStore(delS."FSN Alter Key");
                                                    if FirstStore <> '' then
                                                        Restaurante := FirstStore
                                                    else
                                                        Restaurante := delS."Restaurant No.";
                                                end;

                                            end;
                                        end;

                                        DelStreet_l.Reset();
                                        DelStreet_l.SetRange("Street Name", AddressV);
                                        DelStreet_l.SetRange("Number from", 1);
                                        if DelStreet_l.FindFirst() then begin
                                            DelStreet_l.CalcFields(City);
                                            InputCity := DelStreet_l.City;
                                            InputZipCode := DelStreet_l."Post Code";
                                            InputGrid := DelStreet_l."Grid Code";
                                            Address2V := DelStreet_l."Address 2";
                                        end;
                                        UpdateAddress(DomicilioTake);
                                        FilterAddresPage(DomicilioTake);
                                        UpdateAdressDelOrder();
                                        if POSSESSION.GetValue('CURRORDER') <> '' then begin
                                            if Globals."Order No." = POSSESSION.GetValue('CURRORDER') then begin
                                                if not (Globals."General Status" = Globals."General Status"::ERROR) then
                                                    if Restaurante <> '' then
                                                        FSNDeliveryFunct.ChangeStore(Globals."Order No.", Restaurante, 1);
                                            end;

                                        end;
                                    end;
                                end;
                            end;
                        }

                        field("Restriccion"; FSNDSRestriction)
                        {
                            Caption = 'Restriccion :.';
                            ApplicationArea = All;
                            Editable = false;

                            trigger OnValidate()
                            var
                            begin
                            end;
                        }
                        field("Direccion"; DirectionsV)
                        {
                            Caption = 'Direccion :.';
                            ApplicationArea = All;
                            Editable = true;
                            //ToolTip = DirectionsV;

                            trigger OnValidate()
                            var
                            begin
                                UpdateAddress(DomicilioTake);
                                UpdateAdressDelOrder();
                            end;
                        }

                        field("Direccion 2"; DirectionsV2)
                        {
                            Caption = 'Direccion 2:.';
                            ApplicationArea = All;
                            Editable = true;
                            //ToolTip = DirectionsV;

                            trigger OnValidate()
                            var
                            begin
                                UpdateAddress(DomicilioTake);
                                UpdateAdressDelOrder();
                            end;
                        }
                    }
                }
                field("Sugeridas"; suggest)
                {
                    Caption = 'Sugeridas :.';
                    ApplicationArea = All;
                    Editable = false;

                    trigger OnValidate()
                    var
                    begin
                    end;
                }
                field("Llave Alterna"; FSNAlterKey)
                {
                    Caption = 'Llave Alterna :.';
                    ApplicationArea = All;
                    Editable = false;
                    Visible = false;

                    trigger OnValidate()
                    var
                    begin
                    end;
                }

            }

            group("Detalle Order")
            {
                Caption = 'Detalle de la Orden.';
                part(TransLine; "FSN POSTrans Line")
                {
                    ApplicationArea = All;
                    Caption = 'Transaccion';
                    Editable = false;
                    //SubPageLink = "Receipt No." = FIELD("Order No."), "Entry Status" = const(0);
                    Visible = ProcesarPedido;
                }
            }
            group(Comentarios)
            {
                part(Coment; "FSN Comentario Call")
                {
                    Caption = 'Comentario';
                    Editable = true;
                    //SubPageLink = "No." = FIELD("Phone No.");
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {

            action("Opciones Despacho")
            {
                ApplicationArea = All;
                Caption = 'Opciones Despacho';
                Image = AllLines;
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    PAGELinks: Page "FSN Delivery Store Links";
                    StoreLinksTable: Record "FSN Store Link";
                    DelStreet: Record "LSC Delivery Street";
                    interfaceIntAlterKey: Integer;
                begin

                    interfaceIntAlterKey := FSNAlterKey;
                    DelStreet.RESET;
                    DelStreet.SETRANGE("FSN Alter Key", interfaceIntAlterKey);
                    IF NOT DelStreet.FINDFIRST THEN
                        EXIT;

                    StoreLinksTable.RESET;
                    StoreLinksTable.SETCURRENTKEY("Km Between Points");
                    StoreLinksTable.SETRANGE(StoreLinksTable.Type, StoreLinksTable.Type::StreetAlterKey);
                    StoreLinksTable.SETRANGE(StoreLinksTable."Parent Code", DelStreet."FSN Alter Key Text");
                    IF DelStreet."FSN Distance Order Type" = DelStreet."FSN Distance Order Type"::"Distance Driver" THEN BEGIN
                        StoreLinksTable.SETCURRENTKEY(Sort, "Km Distance Driver");
                        StoreLinksTable.SETFILTER(StoreLinksTable."Km Distance Driver", '>0&<=%1', DelStreet."FSN Distance Allow Km.");
                    END ELSE
                        StoreLinksTable.SETFILTER(StoreLinksTable."Km Between Points", '>0&<=%1', DelStreet."FSN Distance Allow Km.");
                    PAGELinks.SetTableView(StoreLinksTable);
                    PAGELinks.SetActionVisible(true);
                    PAGELinks.Editable(false);
                    PAGELinks.LookupMode(true);
                    PAGELinks.Run();
                end;

            }

            action("Pedido Contacto")
            {
                ApplicationArea = All;
                Caption = 'Pedido Contacto';
                Image = ContactPerson;
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;
                //RunObject = Page "FSN POSTrans Line";

                trigger OnAction()
                var
                    myInt: Integer;
                    PageDeliveryTakeOrder: page "FSN Pedido contacto";
                    DelOrd_1: Record "LSC Delivery Order";
                begin
                    DelOrd_1.SetFilter("Phone No.", PhoneNo);
                    DelOrd_1.SetFilter("Call Cent. Web Service Status", Format(Globals."Call Cent. Web Service Status"::"New-Not Confirmed"));
                    CurrPage.Close();
                    If Globals."Order No." <> '' then begin
                        PageDeliveryTakeOrder.LastPedOrder(Globals);
                    end;
                    PageDeliveryTakeOrder.SetTableView(DelOrd_1);
                    PageDeliveryTakeOrder.Run();
                end;
            }
            action(Historico)
            {
                ApplicationArea = All;
                Image = Answers;
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;
                trigger OnAction()
                var
                    Parameter: Record "FSN Parameter";
                begin
                    RequestID := 'DEL-HISTORICO';
                    if Parameter.Get('ITEM', 'HISTORICO') AND (Parameter.Activo) then begin
                        XMLResponse := Parameter."Web Uri" + Globals."Phone No.";
                        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
                    end;
                end;
            }
            action(Cotizacion)
            {
                ApplicationArea = All;
                Caption = 'Cotizacion';
                Image = MailAttachment;
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;
                trigger OnAction()
                var
                    myInt: Integer;
                begin
                    CotizVisible := true;
                end;
            }

            action("llevarOrder")
            {
                ApplicationArea = All;
                Caption = 'Llevar Pedido';
                ToolTip = 'Permite preparar la Orden';
                Image = Order;
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;
                Visible = llevarPedido;
                trigger OnAction()
                var
                    RetailSetup_l: Record "LSC Retail Setup";
                    SelReceiptNo: Code[50];
                    HospOrderKotStatus: Record "LSC Hosp. Order KOT Status";
                    HospPOSStart: Codeunit "LSC Hospitality POS Startup";
                begin

                    // Bloquear edición si la hora/fecha programada es inválida
                    IF POSSESSION.GetValue('VALRESTAURAN') = 'TRUE' THEN BEGIN
                        Message('No se puede editar el pedido: la fecha/hora programada no es válida para la sucursal seleccionada.');
                        EXIT;
                    END;
                    // Bloquear edición si la hora/fcha programada es inválida
                    IF POSSESSION.GetValue('VALRESTAURAN') = 'TRUE' THEN BEGIN
                        Message('No se puede editar el pedido: la fecha/hora programada no es válida para la sucursal seleccionada.');
                        EXIT;
                    END;
                    IF Restaurante in ['', 'F20'] THEN begin
                        message('Se debe selecionar sala');
                        exit;
                    end;

                    // COMMIT para asegurar persistencia de fecha/hora antes de navegar
                    Commit();

                    //AfterClosingOrderTakeNew(PhoneNo, Restaurante);
                    OpenOrderPOS(Globals."Order No.");
                    CurrPage.Close();
                end;
                //RunObject = Page "Item List";
            }
            action("Editar Orden")
            {
                Caption = 'Editar Orden';
                ToolTip = 'Edita pedido actual';
                Image = Edit;
                ApplicationArea = All;
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;
                Visible = ProcesarPedido;

                trigger OnAction()
                var
                    RetailSetup_l: Record "LSC Retail Setup";
                    SelReceiptNo: Code[50];
                    HospOrderKotStatus: Record "LSC Hosp. Order KOT Status";
                    HospPOSStart: Codeunit "LSC Hospitality POS Startup";
                    PosTransaction: Record "LSC POS Transaction";
                begin
                    IF Restaurante in ['', 'F20'] THEN begin
                        message('Se debe selecionar sala');
                        exit;
                    end;
                    if Globals."Order No." <> POSSESSION.GetValue('CURRORDER') then begin
                        Globals.Reset();
                        if Globals.Get(POSSESSION.GetValue('CURRORDER')) then
                            EditableOrderTake(Globals."Order No.");
                    end else
                        EditableOrderTake(Globals."Order No.");

                    if PosTransaction.Get(Globals."Order No.") then
                        ValidaInfocodigos(PosTransaction, Globals);
                    //CurrPage.Close();
                end;
            }

            action("ProcessOrder")
            {
                ApplicationArea = All;
                Caption = 'Confirmar Pedido';
                ToolTip = 'Envia pedido a la sucursal';
                Image = Action;
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;
                Visible = ProcesarPedido;
                trigger OnAction()
                var
                    ErrorValidation: Text;
                    CheckPayment: Codeunit "FSN Check Payments POS";
                    TEXT000: Label 'NO puede confirmar orden con restaurante F20';
                    TEXT001: Label 'NO puede confirmar orden. Colonia o Calle es requerido';
                    TaskScheduler: Codeunit "Job Create-Invoice";
                    TaskCodeunitId: Integer;
                    PosTransaction: Record "LSC POS Transaction";
                begin
                    if PosTransaction.Get(Globals."Order No.") then
                        ValidaInfocodigos(PosTransaction, Globals);
                    ValidateInventoryECC(PosTransaction);
                    IF NOT CheckPayment.CheckDataPaymentDeliverySend(POSSESSION.GetValue('CURRORDER'), ErrorValidation) THEN BEGIN
                        Message(ErrorValidation);
                        EXIT;
                    END else begin
                        IF POSSESSION.GetValue('VALRESTAURAN') = 'TRUE' THEN BEGIN
                            Message('No se puede confirmar el pedido: la fecha/hora programada no es válida para la sucursal seleccionada.');
                            EXIT;
                        END;
                        if Globals.Name = '' then begin
                            Message('El nombre del cliente es requerido');
                            exit;
                        end;
                        if Globals."Restaurant No." <> 'F20' then begin
                            IF AddressV in ['', '1', '1 '] then
                                Message(TEXT001)
                            else begin
                                if Globals.get(Globals."Order No.") then;
                                ProcessOrderT(Globals."Order No.");
                            end;
                        end else begin
                            Message(TEXT000);
                            exit;
                        end;
                    end;
                end;
            }

            action("Cancelar Pedido")
            {
                ApplicationArea = All;
                Caption = 'Cancelar Pedido';
                ToolTip = 'Cancela el pedido y lo elimina';
                Image = Cancel;
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;

                trigger OnAction()
                begin
                    OrderCancelPressed();
                end;
            }
        }
    }
    var
        IsOpen: Boolean;
        RangesTxt: Text[250];
        POSSESSION: Codeunit "LSC POS Session";
        Globals: Record "LSC Delivery Order";
        DomicilioTake: Option Home,Work,Other,Takeout;
        DomicilioTake2: Option Home,Work,Other,Takeout;
        ChannelV: Text[100];
        POSGUI: Codeunit "LSC POS GUI";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" Temporary;
        Processed: Boolean;
        MsgResult: Text;
        TransactionUse: Record "LSC Transaction in Use on POS";
        DELAmount: Decimal;
        DELDiscount: decimal;
        DELPago: decimal;
        DELBalance: decimal;
        DeliveryStoreLink: Codeunit "FSN Delivery Store Link";
        DelOrdManagement: Codeunit "LSC Delivery Order Management";
        DeliveryContact: Record "LSC Delivery Contact Address";
        FSNTakeOrder: Page "FSN Take Order CC";
        suggest: Text;
        NameV: Text[100];
        AddressV: text[80];
        Address2V: Text[30];
        FSNDSRestriction: text[50];
        DirectionsV: text[100];
        DirectionsV2: Text[250];
        FSNAlterKey: Integer;
        PhoneNo: Code[30];
        DelCustAddr: Record "LSC Delivery Contact Address";
        DelContTEMP: Record Contact;
        Text080: Label 'El restaurante %1 ya está seleccionado. ¿Quieres cambiarlo al restaurante %2?';
        GlobalVisible: Boolean;
        ProcesarPedido: Boolean;
        llevarPedido: Boolean;
        Restaurante: Code[10];
        Estatus: Text;
        CotizVisible: Boolean;
        DelStreet_l: Record "LSC Delivery Street";
        SalesChan: Record "FSN Sales Channel";
        Cotizacion: Text[250];
        EPosCtrl: codeunit "LSC POS Control Interface";
        TimeOrder: Time;
        DateOrder: Date;
        InputZipCode: code[20];
        InputCity: Text[30];
        InputGrid: Code[20];
        OrderProdTime: Integer;
        GlobalMenuLine: Record "LSC POS Menu Line" temporary;
        OrderN: Code[20];
        CUSTOMER: Record Customer;
        Email: Text[100];
        StyleStatus: Option None,Standard,StandardAccent,Strong,StrongAccent,Attention,AttentionAccent,Favorable,Unfavorable,Ambiguous,Subordinate;
        StyleStatusText: Text;
        FSNDeliveryFunct: Codeunit "FSN Delivery Functions Extend";
        OfflineCCWSClient: codeunit "LSC Offl. CC Web Serv. Client";
        PedidoNo: Code[20];
        GlobalContact: Record "Contact" temporary;
        FSNUtility: Codeunit "FSN Utility";
        PosTransL: Record "LSC POS Trans. Line";
        TenderTypeSetup: Record "LSC Tender Type Setup";
        POSCARD: Record "LSC POS Card Entry";
        CCcontroler: Codeunit "FSN CallCenter Controller";
        GlobalParametroPQ: Record "FSN Parameter";
        // Flag: user manually selected the store; don't auto-overwrite until street changes
        StoreEditedManually: Boolean;
        // Per-domicilio manual store memory
        ManualStoreHome: Code[10];
        ManualStoreWork: Code[10];
        ManualStoreOther: Code[10];
        IsManualHome: Boolean;
        IsManualWork: Boolean;
        IsManualOther: Boolean;

    procedure SETGLOBALCONTAC(CONTACT: Record "Contact")
    begin
        GlobalContact.COPY(CONTACT);
    end;

    trigger OnAfterGetRecord()
    var
        pRecRef: RecordRef;
    begin

        if Globals."Order No." <> POSSESSION.GetValue('CURRORDER') then begin
            Globals.Reset();
            if Globals.Get(POSSESSION.GetValue('CURRORDER')) then;
        end;

    end;

    // usa la variable Globals para filtrar delivery order en la pagina.
    procedure SETGLOBALVALUE(var POSDeliveryOrder: Record "LSC Delivery Order")
    begin
        Globals := POSDeliveryOrder;
    end;

    trigger OnOpenPage()
    var
        WSTable: Record "FSN WebServiceTable";
        DelContacAddress: Record "LSC Delivery Contact Address";
        RestaurantNo: Code[10];
        DelStreet: Record "LSC Delivery Street";
        SavedDateText: Text;
        SavedTimeText: Text;
    begin
        IF Globals."Order No." <> '' THEN BEGIN
            IF WSTable.Get(Globals."Order No.") THEN begin
                IF (WSTable.Store IN ['APP', 'EC']) THEN BEGIN
                    IF WSTable."Status WS" <> WSTable."Status WS"::InProcess THEN BEGIN
                        WSTable."Status WS" := WSTable."Status WS"::InProcess;
                        WSTable.Modify();
                        Commit();
                    END;
                END;
            end;

            ValidatePaymentOrder(Globals."Order No.", Globals."Restaurant No.");//muestra total de pago

            DomicilioTake := ValidateDomicilioTake(Globals."Phone No.", Globals."FSN Street Name");//Tipo domicilio

            //LLena variables para mostrar la direccion, segun el tipo domicilio, domicilio por defecto CASA
            DeliveryType(DomicilioTake, Globals."Order No.");

            // Recuperar fecha/hora guardadas desde POSSESSION
            SavedDateText := POSSESSION.GetValue('DEL-PickupDate');
            SavedTimeText := POSSESSION.GetValue('DEL-PickupTime');
            if SavedDateText <> '' then
                Evaluate(DateOrder, SavedDateText)
            else
                DateOrder := Globals."Order Date";
            if SavedTimeText <> '' then begin
                // Recuperar hora desde texto guardado
                if not Evaluate(TimeOrder, SavedTimeText) then
                    TimeOrder := Globals."Contact Pickup Time";
            end else
                TimeOrder := Globals."Contact Pickup Time";

            VisiblePosTransLine(false);//Muestra ficha POS Trans line
        end else begin
            DelContacAddress.Reset();
            DelContacAddress.SetRange("Phone No.", POSSESSION.GetValue('PHONEORDER'));
            DelContacAddress.SetRange("Address Type", DelContacAddress."Address Type"::Home);
            if DelContacAddress.FindFirst() then begin
                SetVariable(DelContacAddress);
                DelStreet.Reset();
                DelStreet.SetRange("Street Name", DelContacAddress."Street Name");
                if DelStreet.FindFirst() then begin
                    RestaurantNo := GetFirstSuggestedStore(DelStreet."FSN Alter Key");
                    if RestaurantNo = '' then
                        RestaurantNo := DelStreet."Restaurant No.";
                end;
                ManualStoreHome := '';
                ManualStoreWork := '';
                ManualStoreOther := '';
                IsManualHome := false;
                IsManualWork := false;
                IsManualOther := false;
                POSSESSION.SetValue('MANUAL_STORE_HOME', '');
                POSSESSION.SetValue('MANUAL_STORE_WORK', '');
                POSSESSION.SetValue('MANUAL_STORE_OTHER', '');
                POSSESSION.SetValue('MANUAL_FLAG_HOME', 'FALSE');
                POSSESSION.SetValue('MANUAL_FLAG_WORK', 'FALSE');
                POSSESSION.SetValue('MANUAL_FLAG_OTHER', 'FALSE');
                AfterClosingOrderTakeNew(POSSESSION.GetValue('PHONEORDER'), RestaurantNo, Globals);
            end;
            NewOrder(OptionOrder(Globals));
            if DelContTEMP.get(POSSESSION.GetValue('PHONEORDER')) then begin
                TimeOrder := Time;
                DateOrder := Today;
                POSSESSION.SetValue('DEL-PickupDate', Format(DateOrder));
                POSSESSION.SetValue('DEL-PickupTime', Format(TimeOrder));
            end;
            VisiblePosTransLine(true);
            ValidatePaymentOrder(Globals."Order No.", Globals."Restaurant No.");//muestra total de pago
        end;
        if Restaurante = 'F20' then begin
            Restaurante := '';
        end;
        if SalesChan.Get(Globals."Order No.") then begin
            if SalesChan."Receipt No" <> '' then begin
                ChannelV := SalesChan.SalesChannel;
            end else
                ChannelV := 'Seleccione canal';
        end else
            ChannelV := 'Seleccione canal';
    end;

    trigger OnclosePage()
    var
        myInt: Integer;
        EPosCtrl: Codeunit "LSC POS Control Interface";
        UsePosTransaction: Record "LSC Transaction in Use on POS";
    begin
        if POSSESSION.GetValue('CLEARCURRORDER') = 'true' then begin
            if UsePosTransaction.get(Globals."Order No.") then begin
                UsePosTransaction.Delete();
                Commit();
            end;

            //POSSESSION.SetValue('PHONEORDER', '');
            POSSESSION.SetValue('CURRORDER', '');
            Clear(ChannelV);
            Clear(Restaurante);
            POSSESSION.SetValue('DEL-OrderStatus', '');
            DELAmount := 0;
            DELDiscount := 0;
            DELPago := 0;
            DELBalance := 0;
            Cotizacion := '';
            DomicilioTake := DomicilioTake::Home;
            PhoneNo := '';
            NameV := '';
            AddressV := '';
            DirectionsV := '';
            DirectionsV2 := '';
            Address2V := '';
            FSNDSRestriction := '';
            Estatus := '';
            suggest := '';
            FSNAlterKey := 0;
            Clear(GlobalMenuLine);
            GlobalMenuLine.DeleteAll();
        end;
    end;

    procedure ValidatePaymentOrder(): Boolean
    var
        myInt: Integer;
        POSTransLine: Record "LSC POS Trans. Line";
        EntryType: Enum "LSC POS Trans. Line Entry Type";
    begin
        POSTransLine.Reset();
        POSTransLine.SetRange("Receipt No.", POSSESSION.GetValue('CURRORDER'));
        POSTransLine.SetRange("Entry Type", EntryType::Payment);
        if POSTransLine.Find('-') then
            exit(true)
        else
            exit(false);
    end;

    //para poder mostrar botones de prcesar.
    procedure VisiblePosTransLine(Vis: Boolean)
    var
        myInt: Integer;
    begin
        llevarPedido := Vis;

        if not Vis then
            ProcesarPedido := true;

    end;

    procedure SetVariable(DelCtAddr: Record "LSC Delivery Contact Address")//15837t
    var
        myInt: Integer;
    begin
        DomicilioTake := DelCtAddr."Address Type";
        suggest := GetStoreLinksSuggest(FSNAlterKey);
        PhoneNo := DelCtAddr."Phone No.";
        NameV := DelContTEMP.Name;
        AddressV := DelCtAddr."Street Name";
        Address2V := DelCtAddr."Address 2";
        InputCity := DelStreet_l.City;
        InputZipCode := DelCtAddr."Post Code";
        FSNDSRestriction := DelStreet_l.Restriction;
        DirectionsV := DelCtAddr.Directions;
        DirectionsV2 := DelCtAddr."FSN Direction";
        InputGrid := DelCtAddr."Grid Code";
        OrderProdTime := 1;
    end;

    //si existe Order No. llena las variables con la informacion de la Delivery Order.
    procedure DeliveryType(DeliveryTakeType: Option Home,Work,Other,Takeout; ORDERNO: Code[20])
    var
        DeliveryOrderV: Record "LSC Delivery Order";
        DelCustAddre: Record "LSC Delivery Contact Address";
        POSTransaction: Record "LSC POS Transaction";
        SavedDateText: Text;
        SavedTimeText: Text;
        HasSavedDate: Boolean;
        HasSavedTime: Boolean;

    begin
        SavedDateText := POSSESSION.GetValue('DEL-PickupDate');
        SavedTimeText := POSSESSION.GetValue('DEL-PickupTime');
        HasSavedDate := false;
        HasSavedTime := false;
        if SavedDateText <> '' then
            HasSavedDate := Evaluate(DateOrder, SavedDateText);
        if SavedTimeText <> '' then
            HasSavedTime := Evaluate(TimeOrder, SavedTimeText);
        if DeliveryOrderV.Get(ORDERNO) then begin//Actualiza la pagina con la nueva direccion
            if POSTransaction.Get(DeliveryOrderV."Order No.") then begin
                if POSTransaction."Staff ID" <> POSSESSION.StaffID() then
                    POSSESSION.SetValue('VALFSN-SALESSTAFF', POSTransaction."Sales Staff");
                POSSESSION.SetTempStoreTerminal(POSTransaction."Store No.", POSTransaction."POS Terminal No.", POSTransaction."Sales Type");
            end;
            DelCustAddre.Reset();
            DelCustAddre.SetRange("Phone No.", DeliveryOrderV."Phone No.");
            DelCustAddre.SetRange("Address Type", DeliveryTakeType);
            if DelCustAddre.FindFirst() then;
            DelStreet_l.Reset();
            DelStreet_l.SetRange("Street Name", DelCustAddre."Street Name");
            if DelStreet_l.FindFirst() then begin
                DeliveryOrderV."FSN Alter Key" := DelStreet_l."FSN Alter Key";
                if DeliveryOrderV.Directions = '' then
                    DeliveryOrderV.Directions := DelCustAddre.Directions;
                if DeliveryOrderV.Address = '' then
                    DeliveryOrderV.Address := DelCustAddre."Street Name";
            end;
            if HasSavedDate then
                DeliveryOrderV."Order Date" := DateOrder;
            if HasSavedTime then
                DeliveryOrderV."Contact Pickup Time" := TimeOrder;

            if not (HasSavedDate or HasSavedTime) then
                if (DeliveryOrderV."Order Date" <= Today) AND (DeliveryOrderV."Contact Pickup Time" < Time) then begin
                    DeliveryOrderV."Order Date" := Today;
                    DeliveryOrderV."Contact Pickup Time" := Time;
                end;
            DeliveryOrderV.Modify();
            Commit();
            //Estatus := Format(DeliveryOrderV."General Status");
            Estatus := Format(DeliveryOrderV."Call Cent. Web Service Status");
            // Resolve store based on per-domicilio manual memory; otherwise use order's current store
            if IsManualForType(DeliveryTakeType) then
                Restaurante := GetManualStoreForType(DeliveryTakeType)
            else
                Restaurante := DeliveryOrderV."Restaurant No.";
            StoreEditedManually := IsManualForType(DeliveryTakeType);
            PhoneNo := DeliveryOrderV."Phone No.";
            if not HasSavedTime then
                TimeOrder := DeliveryOrderV."Contact Pickup Time";
            if not HasSavedDate then
                DateOrder := DeliveryOrderV."Order Date";
            // Se removió el pop-up de solo nombre de día
            NameV := DeliveryOrderV.Name;
            AddressV := DeliveryOrderV.Address;
            //AddressV := CopyStr(DeliveryOrderV.Address, 3, 30);
            Address2V := DeliveryOrderV."Address 2";
            FSNDSRestriction := DeliveryOrderV."FSN DS Restriction";
            DirectionsV := DeliveryOrderV."Directions";
            DirectionsV2 := DelCustAddre."FSN Direction";
            suggest := GetStoreLinksSuggest(DeliveryOrderV."FSN Alter Key");
            FSNAlterKey := DeliveryOrderV."FSN Alter Key";
            POSSESSION.SetValue('DEL-OrderStatus', Format(DeliveryOrderV."General Status"));
            POSSESSION.SetValue('PHONEORDER', DeliveryOrderV."Phone No.");
            ProStyleStutus(Format(DeliveryOrderV."General Status"));
            UpdateContact(ORDERNO);
            PedidoNo := ORDERNO;
            POSSESSION.SetValue('CLEARCURRORDER', 'true');
            POSSESSION.SetValue('CURRORDER', ORDERNO);
            POSSESSION.SetValue('DEL-PickupDate', Format(DateOrder));
            POSSESSION.SetValue('DEL-PickupTime', Format(TimeOrder));
            UpdateAddress(DeliveryTakeType);
        end else begin
            NewOrder(DeliveryTakeType);
        end;
    end;

    procedure ProStyleStutus(TextStatus: Text)
    var
        myInt: Integer;
    begin
        if not (TextStatus in ['ERROR', 'Cancelled']) then
            StyleStatusText := Format(StyleStatus::Favorable)
        else
            StyleStatusText := Format(StyleStatus::Unfavorable);
    end;

    procedure DeliveryStreet(var Street: Record "LSC Delivery Street")
    var
        myInt: Integer;
        interfaceIntAlterKey: Integer;
        ST: Page "LSC Delivery Streets";
        FirstStore: Code[10];
    begin
        AddressV := Street."Street Name";
        Address2V := Street."Address 2";
        // Reset manual flag when street changes and refresh suggestions
        FSNAlterKey := Street."FSN Alter Key";
        StoreEditedManually := false;
        SetManualFlagForType(DomicilioTake, false);
        suggest := GetStoreLinksSuggest(FSNAlterKey);

        if not IsManualForType(DomicilioTake) then begin
            FirstStore := GetFirstSuggestedStore(FSNAlterKey);
            if FirstStore <> '' then
                Restaurante := FirstStore;
        end;
        if Format(Street."FSN Last Valid Time") <> '' then begin
            FSNDSRestriction := 'Valido hasta' + ' ' + Format(Street."FSN Last Valid Time");
        end else
            FSNDSRestriction := '';
    end;
    //Arma la nueva orden y llena las variables de la pagina.
    procedure NewOrder(DeliveryOrderType: Option Home,Work,Other,Takeout)
    var
        myInt: Integer;
        POSMenuLineV: Record "LSC POS Menu Line";
        DelPanelUtility: Codeunit "LSC Del. POS Panel Utilities";
    begin
        if Restaurante = '' then
            Restaurante := 'F20';
        if POSSESSION.GetValue('PHONEORDER') <> '' then begin
            if DelContTEMP.get(POSSESSION.GetValue('PHONEORDER')) then BEGIN
                DelContTEMP."LSC Next Order Date" := Today;
                DelContTEMP."LSC Next Order Time" := Time;
                DelContTEMP."LSC Pre-Order Print DateTime" := 0DT;
                DelContTEMP."LSC Next Order Selection" := DeliveryOrderType;
                if DelContTEMP."LSC Next Order Restaurant" = '' then
                    DelContTEMP."LSC Next Order Restaurant" := Restaurante;
                DelContTEMP.Modify();
                Commit();
                PhoneNo := POSSESSION.GetValue('PHONEORDER');
                FilterAddresPage(DeliveryOrderType);
                Estatus := Format(Globals."General Status"::"In Process");
                //UpdateAddress(DeliveryOrderType);
            END;
        end;
    end;

    Procedure FilterAddresPage(FilteryOrderType: Option Home,Work,Other,Takeout)
    var
    begin
        DelCustAddr.Reset();
        if DelCustAddr.Get(PhoneNo, FilteryOrderType) then begin
            //IF DomicilioTake <> DelCustAddr."Address Type"::Takeout then begin
            If not ((Globals."General Status" = Globals."General Status"::ERROR)) then
                If not ((Globals."Call Cent. Web Service Status" IN [Globals."Call Cent. Web Service Status"::"Cancelled-Sent", Globals."Call Cent. Web Service Status"::"Cancelled-Not Sent",
            Globals."Call Cent. Web Service Status"::"Changed-Sent", Globals."Call Cent. Web Service Status"::"New-Sent"])) THEN BEGIN
                    if (Globals."Restaurant No." <> 'F20') and (not IsManualForType(FilteryOrderType)) then
                        Restaurante := Globals."Restaurant No.";
                end;
            //end;
            DelStreet_l.Reset();
            DelStreet_l.SetRange("Street Name", DelCustAddr."Street Name");//CopyStr(Rec.Address, 3, 30)
            DelStreet_l.SetRange("Number from", 1);
            if DelCustAddr."Post Code" <> '' then
                DelStreet_l.SetRange("Post Code", DelCustAddr."Post Code");
            if DelStreet_l.FindFirst() then begin
                DelStreet_l.CalcFields(City);
                FSNAlterKey := DelStreet_l."FSN Alter Key";
                // If the current domicilio has a remembered manual store, prefer it now
                if IsManualForType(FilteryOrderType) then begin
                    if GetManualStoreForType(FilteryOrderType) <> '' then
                        Restaurante := GetManualStoreForType(FilteryOrderType);
                end;

                IF DelCustAddr."Street Name" <> DelStreet_l."Street Name" THEN
                    DelCustAddr."Street Name" := DelStreet_l."Street Name";

                IF DelCustAddr."Post Code" <> DelStreet_l."Post Code" THEN
                    DelCustAddr."Post Code" := DelStreet_l."Post Code";

                IF DelCustAddr.City <> DelStreet_l.City THEN
                    DelCustAddr.City := DelStreet_l.City;


                IF DelCustAddr."Grid Code" <> DelStreet_l."Grid Code" THEN
                    DelCustAddr."Grid Code" := DelStreet_l."Grid Code";

                DelCustAddr.Modify();
                Commit();
            end else
                clear(FSNAlterKey);

            if DelContTEMP.get(PhoneNo) then BEGIN
                if Restaurante = '' then
                    Restaurante := 'F20';
                if ChangeRestaurant(DelContTEMP, Restaurante) then begin
                    DomicilioTake := DelCustAddr."Address Type";
                    suggest := GetStoreLinksSuggest(FSNAlterKey);
                    PhoneNo := DelCustAddr."Phone No.";
                    NameV := DelContTEMP.Name;
                    AddressV := DelCustAddr."Street Name";
                    Address2V := DelCustAddr."Address 2";
                    InputCity := DelStreet_l.City;
                    InputZipCode := DelCustAddr."Post Code";
                    FSNDSRestriction := DelStreet_l.Restriction;
                    DirectionsV := DelCustAddr.Directions;
                    DirectionsV2 := DelCustAddr."FSN Direction";
                    InputGrid := DelCustAddr."Grid Code";
                    OrderProdTime := 1;
                    //DelOrdManagement.LoadContext(false);
                end;
            end;
        end else
            UpdateAddress(FilteryOrderType);

    end;

    //Actualza Restarante y se valida hora de cierre del restaurante ValidateTimeOnRestChange
    procedure ChangeRestaurant(var DelCont: Record Contact; NewRestaurantNo: Code[10]): Boolean
    var
        ErrorText: Text;
        DelContTemp: Record Contact temporary;
    begin
        DelContTemp.Init();
        DelContTemp := DelCont;
        DelContTemp."LSC Next Order Restaurant" := NewRestaurantNo;
        DelContTemp.Insert();
        //ValidateTimeOnRestChange(DelContTemp, ErrorText, false);

        if ErrorText <> '' then begin
            exit(false);
        end else begin
            if (DelCont."LSC Next Order Restaurant" <> NewRestaurantNo) then begin
                DelCont."LSC Next Order Restaurant" := NewRestaurantNo;
                DelCont.Modify;
            end;
            exit(true);
        end;

        Clear(DelContTemp);
        DelContTemp.DeleteAll();
    end;

    //Actualiza la Direccion, segun el tipo Domicilio.
    procedure UpdateAddress(DeliveryType: Option Home,Work,Other,Takeout)
    var
        DelCustAddr: Record "LSC Delivery Contact Address";
        HospSetup: Record "LSC Hospitality Setup";
    begin
        if not DelCustAddr.Get(PhoneNo, DeliveryType) then begin
            DelCustAddr.Init;
            DelCustAddr."Phone No." := PhoneNo;
            DelCustAddr."Address Type" := DeliveryType;// - 1; Prueba 
            Clear(AddressV);
            Clear(Address2V);
            Clear(InputZipCode);
            Clear(InputCity);
            Clear(DirectionsV);
            Clear(DirectionsV2);
            // Don't clear the store if the user picked it manually for this domicilio
            if not IsManualForType(DeliveryType) then
                Clear(Restaurante);
            Clear(InputGrid);
            Clear(suggest);

        end;
        DomicilioTake := DeliveryType;
        if CopyStr(AddressV, 1, 2) = '1 ' then
            DelCustAddr."Street Name" := CopyStr(AddressV, 3, 30)
        else
            DelCustAddr."Street Name" := AddressV;
        DelCustAddr."Street No." := Format(1);
        DelCustAddr."Address 2" := Address2V;
        DelCustAddr.Directions := DirectionsV;
        DelCustAddr."FSN Direction" := DirectionsV2;
        DelCustAddr.City := InputCity;
        DelCustAddr."Post Code" := InputZipCode;
        DelCustAddr."Grid Code" := InputGrid;
        IF Restaurante = '' then begin
            If POSSESSION.GetValue('CURRORDER') <> '' then begin
                If (Globals."General Status" = Globals."General Status"::ERROR) OR ((Globals."Call Cent. Web Service Status" IN [Globals."Call Cent. Web Service Status"::"Cancelled-Sent",
                                                   Globals."Call Cent. Web Service Status"::"Changed-Sent", Globals."Call Cent. Web Service Status"::"New-Sent"])) THEN BEGIN
                    Restaurante := Globals."Restaurant No.";
                    //UpdateRestaurante(Restaurante);
                end;
            end;
        end ELSE
            DelCustAddr."Restaurant No." := Restaurante;
        DelCustAddr."Grid Code" := InputGrid;

        if not DelCustAddr.Modify(true) then
            DelCustAddr.Insert(true);

        Commit;
    end;

    //Muestra salas sugeridas
    procedure GetStoreLinksSuggest(AlterKey: Integer): Text[250]
    var
        DelStreet_l: Record "LSC Delivery Street";
        FirstSuggest: Text[10];
        dashPos: Integer;
    begin
        DelStreet_l.Reset();
        DelStreet_l.SetRange("FSN Alter Key", AlterKey);
        if DelStreet_l.FindFirst() then begin
            suggest := DeliveryStoreLink.DelSuggestStoreText(DelStreet_l, 4);
            if suggest <> '' then begin
                dashPos := StrPos(suggest, '-');
                if dashPos > 0 then
                    FirstSuggest := CopyStr(suggest, 1, dashPos - 1)
                else
                    FirstSuggest := suggest;
                if FirstSuggest = '' then
                    FirstSuggest := suggest;
                if not IsManualForType(DomicilioTake) then;
                //Restaurante := FirstSuggest;
            end;
            exit(suggest);
        end;
        exit('');
    end;

    // Returns the first suggested store code for a given street Alter Key (or '' if none)
    local procedure GetFirstSuggestedStore(AlterKey: Integer): Code[10]
    var
        DelStreet_l: Record "LSC Delivery Street";
        suggestText: Text[250];
        dashPos: Integer;
        firstPart: Text[50];
        codeVal: Code[10];
    begin
        Clear(codeVal);
        DelStreet_l.Reset();
        DelStreet_l.SetRange("FSN Alter Key", AlterKey);
        if DelStreet_l.FindFirst() then begin
            suggestText := DeliveryStoreLink.DelSuggestStoreText(DelStreet_l, 4);
            if suggestText <> '' then begin
                dashPos := StrPos(suggestText, '-');
                if dashPos > 0 then begin
                    firstPart := CopyStr(suggestText, 1, dashPos - 1);
                end else begin
                    firstPart := suggestText;
                end;
                // Trim spaces from both ends
                firstPart := DelChr(firstPart, '<', ' ');
                firstPart := DelChr(firstPart, '>', ' ');
                Evaluate(codeVal, firstPart);
                exit(codeVal);
            end;
        end;
        exit('');
    end;

    //valida el Tipo domicilio
    procedure ValidateDomicilioTake(Phone: Code[30]; StreetName: Text[50]): Option
    var
    begin
        DeliveryContact.Reset();
        DeliveryContact.SetRange("Phone No.", Phone);
        DeliveryContact.SetRange("Address Type", OptionOrder(Globals));
        if DeliveryContact.FindFirst() then begin
            exit(DeliveryContact."Address Type");
        end;
    end;

    // Devuelve el día de la semana (1=Monday .. 7=Sunday) para una fecha
    local procedure GetDayOfWeekFromDate(MyDate: Date): Integer
    var
        DayOfWeek: Integer;
    begin
        DayOfWeek := DATE2DWY(MyDate, 1);
        exit(DayOfWeek);
    end;

    // Muestra un Message con el nombre del día para la fecha indicada
    local procedure ShowDayNameFromDate(MyDate: Date)
    var
        DayOfWeek: Integer;
        DayName: Text;
    begin
        DayOfWeek := GetDayOfWeekFromDate(MyDate);
        case DayOfWeek of
            1:
                DayName := 'Monday';
            2:
                DayName := 'Tuesday';
            3:
                DayName := 'Wednesday';
            4:
                DayName := 'Thursday';
            5:
                DayName := 'Friday';
            6:
                DayName := 'Saturday';
            7:
                DayName := 'Sunday';
        end;

        Message('The day is %1', DayName);
    end;

    // Devuelve el nombre del día en español
    local procedure GetDayNameEs(MyDate: Date): Text
    var
        DayOfWeek: Integer;
        DayName: Text[30];
    begin
        DayOfWeek := GetDayOfWeekFromDate(MyDate);
        case DayOfWeek of
            1:
                DayName := 'lunes';
            2:
                DayName := 'martes';
            3:
                DayName := 'miércoles';
            4:
                DayName := 'jueves';
            5:
                DayName := 'viernes';
            6:
                DayName := 'sábado';
            7:
                DayName := 'domingo';
        end;
        exit(DayName);
    end;

    // Revisa si la tienda está abierta en la fecha y hora dadas, devolviendo también el/los rangos
    local procedure IsStoreOpenAt(RestNo: Code[10]; TheDate: Date; TheTime: Time; var RangesText: Text[250]): Boolean
    var
        CalendarType: Integer;
        StepText: Text[250];
    begin
        Clear(RangesText);
        CalendarType := GetCalendarTypeForCurrentSelection();

        // 1) Cerrado + Include All Week Days = false (LineType=2, CalendarType=1)
        if ValidateClosedCalendarStep(1, RestNo, TheDate, TheTime, CalendarType, false, StepText) then begin
            RangesText := StepText;
            exit(false);
        end;

        // 2) Cerrado + Include All Week Days = true (LineType=2, CalendarType=1)
        if ValidateClosedCalendarStep(2, RestNo, TheDate, TheTime, CalendarType, true, StepText) then begin
            RangesText := StepText;
            exit(false);
        end;

        // 3) Temporal + Include All Week Days = false
        if ValidateCalendarStep(3, 'Temporal', RestNo, TheDate, TheTime, CalendarType, 1, false, true, StepText) then begin
            RangesText := StepText;
            exit(true);
        end;

        RangesText := StepText;
        // 4) Temporal + Include All Week Days = true
        if ValidateCalendarStep(4, 'Temporal', RestNo, TheDate, TheTime, CalendarType, 1, true, false, StepText) then begin
            RangesText := StepText;
            exit(true);
        end;

        RangesText := StepText;
        // 5) Normal + Include All Week Days = false
        if ValidateCalendarStep(5, 'Normal', RestNo, TheDate, TheTime, CalendarType, 0, false, true, StepText) then begin
            RangesText := StepText;
            exit(true);
        end;

        RangesText := StepText;
        // 6) Normal + Include All Week Days = true
        if ValidateCalendarStep(6, 'Normal', RestNo, TheDate, TheTime, CalendarType, 0, true, false, StepText) then begin
            RangesText := StepText;
            exit(true);
        end;

        RangesText := StepText;
        exit(false);
    end;

    local procedure ValidateClosedCalendarStep(StepNo: Integer; RestNo: Code[10]; TheDate: Date; TheTime: Time; CalendarType: Integer; IncludeAllWeekDays: Boolean; var DebugText: Text[250]): Boolean
    var
        RCL: Record "LSC Retail Calendar Line";
        InfiniteDate: Date;
        HasLines: Boolean;
        DateOk: Boolean;
        TimeOk: Boolean;
        HasEndDate: Boolean;
        DateRangeText: Text[80];
        TimeRangeText: Text[40];
    begin
        InfiniteDate := DMY2Date(1, 1, 1753);
        HasLines := false;
        Clear(DebugText);

        RCL.Reset();
        RCL.SetCurrentKey("Calendar ID", "Calendar Type", "Line Type", "Include All Week Days", "Starting Date", "Time From");
        RCL.SetRange("Calendar ID", RestNo);
        RCL.SetRange("Calendar Type", CalendarType);
        RCL.SetRange("Line Type", 2);
        RCL.SetRange("Include All Week Days", IncludeAllWeekDays);
        RCL.SetFilter("Starting Date", '<=%1', TheDate);

        if RCL.FindSet() then
            repeat
                HasLines := true;
                HasEndDate := (RCL."Ending Date" <> 0D) and (RCL."Ending Date" <> InfiniteDate);

                if HasEndDate then
                    DateOk := (RCL."Starting Date" <= TheDate) and (TheDate <= RCL."Ending Date")
                else
                    if IncludeAllWeekDays then
                        DateOk := (RCL."Starting Date" <= TheDate)
                    else
                        DateOk := (RCL."Starting Date" = TheDate);

                if DateOk then begin
                    TimeOk := (TheTime >= RCL."Time From") and (TheTime < RCL."Time To");
                    if TimeOk then begin
                        if HasEndDate then
                            DateRangeText := Format(RCL."Starting Date") + ' -> ' + Format(RCL."Ending Date")
                        else
                            if IncludeAllWeekDays then
                                DateRangeText := Format(RCL."Starting Date") + ' -> INFINITO'
                            else
                                DateRangeText := Format(RCL."Starting Date");

                        TimeRangeText := Format(RCL."Time From") + ' - ' + Format(RCL."Time To");
                        DebugText := StrSubstNo('Validación %1 Cerrado CERRADA | Sala %2 | CalendarType=%3 | LineType=2 | IncludeAllWeekDays=%4 | Fecha=%5 | Hora=%6 | Rango=%7', StepNo, RestNo, CalendarType, IncludeAllWeekDays, DateRangeText, Format(TheTime), TimeRangeText);
                        exit(true);
                    end;
                end;
            until RCL.Next() = 0;

        if HasLines then
            DebugText := StrSubstNo('Validación %1 Cerrado OK | Sala %2 | CalendarType=%3 | LineType=2 | IncludeAllWeekDays=%4 | Fecha=%5 | Hora=%6 | No coincide con rango de cierre', StepNo, RestNo, CalendarType, IncludeAllWeekDays, Format(TheDate), Format(TheTime))
        else
            DebugText := StrSubstNo('Validación %1 Cerrado OK | Sala %2 | CalendarType=%3 | LineType=2 | IncludeAllWeekDays=%4 | Fecha=%5 | Hora=%6 | Sin líneas de cierre', StepNo, RestNo, CalendarType, IncludeAllWeekDays, Format(TheDate), Format(TheTime));

        exit(false);
    end;

    local procedure GetCalendarTypeFromOrderOption(OrderTypeOption: Integer): Integer
    begin
        // Regla de negocio: Delivery=1, Para llevar=3
        if OrderTypeOption = 4 then
            exit(3);

        exit(1);
    end;

    local procedure GetCalendarTypeForCurrentSelection(): Integer
    begin
        // Prioridad: domicilio seleccionado actualmente en pantalla.
        // Si es PARA LLEVAR, debe consultar siempre CalendarType=3.
        if DomicilioTake = DomicilioTake::Takeout then
            exit(3);

        // Fallback: tipo de orden en cabecera.
        exit(GetCalendarTypeFromOrderOption(Globals."Order Type Option"));
    end;

    local procedure ValidateCalendarStep(StepNo: Integer; StepKind: Text[20]; RestNo: Code[10]; TheDate: Date; TheTime: Time; CalendarType: Integer; LineType: Integer; IncludeAllWeekDays: Boolean; ExactDateOnly: Boolean; var DebugText: Text[250]): Boolean
    var
        RCL: Record "LSC Retail Calendar Line";
        InfiniteDate: Date;
        HasLines: Boolean;
        DateOk: Boolean;
        TimeOk: Boolean;
        HasEndDate: Boolean;
        DateRangeText: Text[80];
        TimeRangeText: Text[40];
    begin
        InfiniteDate := DMY2Date(1, 1, 1753);
        HasLines := false;
        Clear(DebugText);

        RCL.Reset();
        RCL.SetCurrentKey("Calendar ID", "Calendar Type", "Line Type", "Include All Week Days", "Starting Date", "Time From");
        RCL.SetRange("Calendar ID", RestNo);
        RCL.SetRange("Calendar Type", CalendarType);
        RCL.SetRange("Line Type", LineType);
        RCL.SetRange("Include All Week Days", IncludeAllWeekDays);
        // Siempre considerar rangos desde la fecha de inicio hacia adelante
        RCL.SetFilter("Starting Date", '<=%1', TheDate);

        if RCL.FindSet() then
            repeat
                HasLines := true;

                HasEndDate := (RCL."Ending Date" <> 0D) and (RCL."Ending Date" <> InfiniteDate);

                // Reglas solicitadas:
                // 1) Si tiene fecha fin, validar dentro del rango [inicio..fin] siempre.
                // 2) Si no tiene fecha fin y IncludeAllWeekDays = 0, solo aplica al día exacto de inicio.
                // 3) Si no tiene fecha fin y IncludeAllWeekDays = 1, aplica desde inicio en adelante (infinito).
                if HasEndDate then
                    DateOk := (RCL."Starting Date" <= TheDate) and (TheDate <= RCL."Ending Date")
                else
                    if IncludeAllWeekDays then
                        DateOk := (RCL."Starting Date" <= TheDate)
                    else
                        DateOk := (RCL."Starting Date" = TheDate);

                if DateOk then begin
                    TimeOk := (TheTime >= RCL."Time From") and (TheTime < RCL."Time To");
                    if TimeOk then begin
                        if ExactDateOnly then
                            DateRangeText := Format(RCL."Starting Date")
                        else
                            DateRangeText := Format(RCL."Starting Date") + ' -> ' + Format(RCL."Ending Date");

                        TimeRangeText := Format(RCL."Time From") + ' - ' + Format(RCL."Time To");
                        DebugText := StrSubstNo('Validación %1 %2 OK | Sala %3 | CalendarType=%4 | LineType=%5 | IncludeAllWeekDays=%6 | Fecha=%7 | Hora=%8 | Rango=%9', StepNo, StepKind, RestNo, CalendarType, LineType, IncludeAllWeekDays, DateRangeText, Format(TheTime), TimeRangeText);
                        exit(true);
                    end;
                end;
            until RCL.Next() = 0;

        if HasLines then begin
            DebugText := StrSubstNo('Validación %1 %2 FAIL | Sala %3 | CalendarType=%4 | LineType=%5 | IncludeAllWeekDays=%6 | Fecha=%7 | Hora=%8 | Fuera de vigencia por rango de fechas', StepNo, StepKind, RestNo, CalendarType, LineType, IncludeAllWeekDays, Format(TheDate), Format(TheTime));
        end else begin
            DebugText := StrSubstNo('Validación %1 %2 FAIL | Sala %3 | CalendarType=%4 | LineType=%5 | IncludeAllWeekDays=%6 | Fecha=%7 | Hora=%8 | Sin líneas candidatas', StepNo, StepKind, RestNo, CalendarType, LineType, IncludeAllWeekDays, Format(TheDate), Format(TheTime));
        end;

        exit(false);
    end;

    procedure OptionOrder(OptOrder: Record "LSC Delivery Order"): Option
    var
        myInt: Integer;
        TypeO: Option;
    begin

        CASE OptOrder."Order Type Option" OF
            1:
                exit(DomicilioTake2::Home);
            2:
                exit(DomicilioTake2::Work);
            3:
                exit(DomicilioTake2::Other);
            4:
                exit(DomicilioTake2::Takeout);
        END;
    end;
    /// Se valida los montos de la orden, por si se edita la orden y las variables de session aun esten vacias
    procedure ValidatePaymentOrder(OrderNo: Code[20]; Restauran: Code[10])
    var
        PosTransaction: Record "LSC POS Transaction";
    begin
        PosTransaction.Reset();
        if PosTransaction.Get(OrderNo) then begin

            PosTransaction.CalcFields("Gross Amount", PosTransaction."Line Discount", "Income/Exp. Amount");

            DELAmount := PosTransaction."Gross Amount" + PosTransaction."Line Discount" + PosTransaction."Income/Exp. Amount";

            DELDiscount := (-(PosTransaction."Line Discount"));

            DELPago := PosTransaction."Gross Amount" + PosTransaction."Income/Exp. Amount";

            DELBalance := DELAmount - DELPago + DELDiscount;
        end;
    end;

    //Grea Delivery Order y pos Transaction y levanta el panel POS.
    procedure EditableOrderTake(Orden: code[20])
    var
        myInt: Integer;
        HosPosStartup: Codeunit "LSC Hospitality POS Startup";
        HT: Codeunit "LSC POS Control Interface";
        POSTransac: Codeunit "LSC POS Transaction";
        POSTransactionBK: Record "LSC POS Transaction";
        OrderOrderPanel: Record "LSC POS Panel";
        CommFilterFieldNo: array[10] of Integer;
        CommFilterText: array[10] of Text;
        DeliveryOrderFilt: Record "LSC Delivery Order";
        TmpMenuLine: Record "LSC POS Menu Line" temporary;
        DeliveryOrderManagement: Codeunit "LSC Delivery Order Management";
        DelOrderinfocode: Record "LSC Delivery Order";
    begin
        POSTransactionBK.Reset();
        iF POSTransactionBK.GET(Orden) THEN begin
            CCcontroler.SetReceipt(POSTransactionBK."Receipt No.");
            possession.SetTempStoreTerminal(POSTransactionBK."Store No.", POSTransactionBK."POS Terminal No.", POSTransactionBK."Sales Type");
            POSSESSION.SetValue('CLEARCURRORDER', 'false');
            CurrPage.Close();
            POSSESSION.SetValue('CURRORDER', POSTransactionBK."Receipt No.");
            HosPosStartup.DirectEdit(true);
        end;
    end;

    //crea Delivery Order y pos transaccion, se usa procedimiento nativo.
    procedure AfterClosingOrderTakeNew(PhoneNoT: Code[30]; RestaurantNo: Code[10]; var DOrder: Record "LSC Delivery Order")
    var
        LastSlipNo: Code[20];
        OrderNo: Code[20];
        TransHdr: Record "LSC Transaction Header";
        PosTrans: Record "LSC POS Transaction";
        LocalStore: Record "LSC Store";
        CallCenterPOSTermAssignm: Record "LSC CC POS Term. Assignm.";
        Text089: Label 'No se encontró ninguna entrada en la tabla %1 para el centro de llamadas %2 y el restaurante %3';
        Text085: Label 'Se debe dedicar un %1 para el centro de llamadas %2 y el restaurante %3 en la tabla %4';
        Text090: Label 'Ocurrió un error al insertar en la tabla %1. Intentar otra vez.';
        DelOrder: Record "LSC Delivery Order";
        PosTerminal: Record "LSC POS Terminal";
        PosFunc: Codeunit "LSC POS Functions";
        SalesType: Integer;
        SalesTypes: Record "LSC Sales Type";
        POSTransaction: Record "LSC POS Transaction";
        OrderDateTime: DateTime;
        errorText: Text;
        POSMenuLineTemp: Record "LSC POS Menu Line";
        HosPosStartup: Codeunit "LSC Hospitality POS Startup";
        RetailSetup_l: Record "LSC Retail Setup";
        NoSeriesMgt: Codeunit NoSeriesManagement;
        DeliveryContAddress: Record "LSC Delivery Contact Address";
        PosInfocode: Record "LSC POS Trans. Infocode Entry";
    begin
        IF RestaurantNo = '' then
            RestaurantNo := 'F20';
        if DelContTEMP.get(PhoneNoT) then;
        SalesType := 1;
        LocalStore.Get('F20');
        PosTerminal.Get(POSSESSION.TerminalNo);
        DelContTEMP."LSC Next Order Selection" := SalesType;
        DelContTEMP."LSC Next Order Date" := DateOrder;
        DelContTEMP."LSC Next Order Time" := TimeOrder;
        DelContTEMP."LSC Next Order Restaurant" := RestaurantNo;
        DelContTEMP.Modify();
        Commit();
        Restaurante := RestaurantNo;

        if LocalStore."No." <> RestaurantNo then begin  // order is made in call center, need to change store and pos terminal
            if not CallCenterPOSTermAssignm.Get(LocalStore."No.", RestaurantNo) then begin
                Message(StrSubstNo(Text089, CallCenterPOSTermAssignm.TableCaption, LocalStore."No.", RestaurantNo));
                exit;
            end;

            if CallCenterPOSTermAssignm."Rest. POS Terminal" = '' then begin
                Message(
                  StrSubstNo(
                    Text085, PosTerminal.TableCaption, LocalStore."No.", RestaurantNo, CallCenterPOSTermAssignm.TableCaption));
                exit;
            end;

            POSSESSION.SetTempStoreTerminal(RestaurantNo, CallCenterPOSTermAssignm."Rest. POS Terminal", DOrder."Sales Type");
        end;

        RetailSetup_l.Get();
        if RetailSetup_l."FSN Is Local Receipt" and (RetailSetup_l."FSN Last Slipt No." <> '') then begin

        end;

        DOrder.Validate("Order Type Option", SalesType);

        PosFunc.ReadLocalVar(LastSlipNo);

        OrderNo := PosFunc.InsertTmpTrans(LastSlipNo, '', DelOrder."Sales Type", 0, false, '');
        PosTrans.Get(OrderNo);

        Commit;

        POSSESSION.SetValue('CURRORDER', OrderNo);
        //Commit;

        if not DelOrdManagement.UpdateOrder(OrderNo, DelContTEMP, true, true, true) then begin
            POSSESSION.SetTempStoreTerminal('', '', DOrder."Sales Type");
            Message(StrSubstNo(Text090, DOrder.TableCaption));
            exit;
        end else begin
            if SalesTypes.Get(DOrder."Sales Type") then begin
                IF POSTransaction.Get(POSSESSION.GetValue('CURRORDER')) THEN BEGIN
                    POSTransaction."New Transaction" := false;
                    POSTransaction."Transaction Type" := POSTransaction."Transaction Type"::Sales;
                    POSTransaction."Trans. Date" := Today;
                    POSTransaction."Original Date" := Today;
                    POSTransaction."Trans Time" := Time;
                    IansertNewLinePosTransLine(POSTransaction);
                    if SalesTypes."VAT Bus. Posting Group" <> '' then
                        POSTransaction."VAT Bus.Posting Group" := SalesTypes."VAT Bus. Posting Group";
                    if SalesTypes."Price Group" <> '' then
                        POSTransaction."Price Group Code" := SalesTypes."Price Group";
                    POSTransaction."Sales Type" := SalesTypes.Code;
                    POSTransaction.Modify(true);
                    Commit();
                END;
            end;
        end;

        DOrder.Reset();
        IF DOrder.Get(POSSESSION.GetValue('CURRORDER')) then begin
            if DeliveryContAddress.Get(DOrder."Phone No.", DeliveryContAddress."Address Type"::Home) then begin
                AddressV := DeliveryContAddress."Street Name";
            end;
            DOrder.Validate("Order Type Option", SalesType);
            DOrder.Address := '1' + ' ' + AddressV;
            DOrder."Address 2" := Address2V;
            DOrder.City := DeliveryContAddress.City;
            DOrder."Created at Call Center" := 'F20';
            IF DOrder."Restaurant No." = '' THEN
                DOrder."Restaurant No." := RestaurantNo;
            DOrder."Contact Pickup Time" := time;
            DOrder."Order Date" := Today;
            DOrder."Post Code" := InputZipCode;
            DOrder.Directions := DirectionsV;
            DOrder."FSN Directions" := DirectionsV2;
            DOrder."Grid Code" := DeliveryContAddress."Grid Code";
            DOrder."Sales Type" := SalesTypes.Code;
            DOrder."FSN Alter Key" := FSNAlterKey;
            DOrder."FSN Street Name" := AddressV;
            DOrder.Modify();
            Commit();
        end;
        ValidaInfocodigos(POSTransaction, DOrder);
        Commit();
        if not DOrder.Get(OrderNo) then begin
            Message(StrSubstNo(Text090, DOrder.TableCaption));
            exit;
        end;
    end;

    local procedure ValidaInfocodigos(PosTrans: Record "LSC POS Transaction"; DOrder: Record "LSC Delivery Order")
    var
        PosInfocode: Record "LSC POS Trans. Infocode Entry";
    begin

        PosInfocode.Init;
        PosInfocode."Receipt No." := PosTrans."Receipt No.";
        PosInfocode."Transaction Type" := 0;
        PosInfocode."Line No." := 1;
        PosInfocode.Infocode := 'DNAME';
        PosInfocode.Information := DOrder.Name;
        PosInfocode."Store No." := PosTrans."Store No.";
        PosInfocode.Date := Today();
        PosInfocode.Time := Time();
        PosInfocode."POS Terminal No." := POSSESSION.TerminalNo;
        PosInfocode."Staff ID" := DOrder."Order Taker";
        if not PosInfocode.Insert(true) then
            PosInfocode.Modify(true);

        if DOrder.Address <> '' then begin
            PosInfocode.Infocode := 'DADDRESS';
            PosInfocode."Line No." := 2;
            PosInfocode.Information := DOrder.Address;
            if not PosInfocode.Insert(true) then
                PosInfocode.Modify(true);
        end;

        if DOrder."Address 2" <> '' then begin
            PosInfocode.Infocode := 'DADDRESS2';
            PosInfocode."Line No." := 3;
            PosInfocode.Information := DOrder."Address 2";
            if not PosInfocode.Insert(true) then
                PosInfocode.Modify(true);
        end;

        Commit;

        if DOrder.City <> '' then begin
            PosInfocode.Infocode := 'DCITYZIP';
            PosInfocode."Line No." := 4;
            PosInfocode.Information := DOrder.City + ' ' + DOrder."Post Code";
            if not PosInfocode.Insert(true) then
                PosInfocode.Modify(true);
        end;

        if DOrder."Grid Code" <> '' then begin
            PosInfocode.Infocode := 'DGRID';
            PosInfocode."Line No." := 5;
            PosInfocode.Information := DOrder."Grid Code";
            if not PosInfocode.Insert(true) then
                PosInfocode.Modify(true);
        end;

        if DOrder.Directions <> '' then begin
            PosInfocode.Infocode := 'DDIRECTION';
            PosInfocode."Line No." := 6;
            PosInfocode.Information := DOrder.Directions;
            if not PosInfocode.Insert(true) then
                PosInfocode.Modify(true);
        end;
    end;

    procedure ValidateInventoryECC(PosTransaction: Record "LSC POS Transaction")
    var
        POSTransLineBK: Record "LSC POS Trans. Line";
        ItemUM: Record "Item Unit of Measure";
        ItemLogTmp: Record "FSN Inventory Internal Log" temporary;
        InvLookUpTable: Record "LSC Inventory Lookup Table";
        InventoryValue: Decimal;
        Divisor: Decimal;
        InventoryLookUpTable: Record "LSC Inventory Lookup Table";
        param: Record "FSN Parameter";
        ItemStatus: Record "LSC Item Status Link";
    begin
        param.Reset();
        param.SetRange(param.Grupo, 'INVENTORY');
        param.SetRange(Codigo, 'ITEM');
        param.SetRange(activo, true);
        IF param.FindFirst() THEN begin
            POSTransLineBK.RESET;
            POSTransLineBK.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
            POSTransLineBK.SETRANGE(POSTransLineBK."Receipt No.", PosTransaction."Receipt No.");
            POSTransLineBK.SETRANGE(POSTransLineBK."Entry Type", POSTransLineBK."Entry Type"::Item);
            POSTransLineBK.SETRANGE(POSTransLineBK."Entry Status", POSTransLineBK."Entry Status"::" ");
            POSTransLineBK.SetFilter(POSTransLineBK.Number, '<>%1&<>%2,&<>%3', 'A3256', '70107', 'B0000305');
            IF POSTransLineBK.FIND('-') THEN
                REPEAT
                    ItemStatus.Reset();
                    ItemStatus.SetRange("Item No.", POSTransLineBK.Number);
                    ItemStatus.SetRange("Status Code", 'RECETARIO');
                    if NOT ItemStatus.FindFirst() then begin
                        if STRPOS(param.Valor, POSTransLineBK.Number) = 0 then begin
                            IF ItemUM.GET(POSTransLineBK.Number, POSTransLineBK."Unit of Measure") THEN
                                IF ItemUM."Qty. per Unit of Measure" <> 0 THEN
                                    Divisor := ItemUM."Qty. per Unit of Measure";//DMEDINA10FEB2020+

                            InventoryValue := 0;
                            IF InventoryLookUpTable.GET(POSTransLineBK.Number, POSTransLineBK."Variant Code", POSTransLineBK."Store No.", POSTransLineBK."Lot No.", POSTransLineBK."Serial No.") THEN
                                InventoryValue := InventoryLookUpTable."Net Inventory" / Divisor;
                            if POSTransLineBK.Quantity / Divisor > InventoryValue then begin
                                Error('Inventario no suficiente para el articulo ' + POSTransLineBK.Number + ' en el almacén ' + POSTransLineBK."Store No.");
                                exit;
                            end;
                        END;
                    END;
                UNTIL POSTransLineBK.NEXT = 0;
        end;
    end;

    procedure IansertNewLinePosTransLine(LscPosTransaction: Record "LSC POS Transaction")
    var
        myInt: Integer;
        InsertPOSTransLine: Record "LSC POS Trans. Line";
    begin
        InsertPOSTransLine.reset;
        InsertPOSTransLine.SetRange(InsertPOSTransLine."Store No.", LscPosTransaction."Store No.");
        InsertPOSTransLine.SetRange(InsertPOSTransLine."POS Terminal No.", LscPosTransaction."POS Terminal No.");
        InsertPOSTransLine.SetRange(InsertPOSTransLine."Receipt No.", LscPosTransaction."Receipt No.");
        InsertPOSTransLine.SetRange(InsertPOSTransLine."Line No.", 1);
        IF not InsertPOSTransLine.FindFirst() THEN BEGIN
            InsertPOSTransLine.Init();
            InsertPOSTransLine."Store No." := LscPosTransaction."Store No.";
            InsertPOSTransLine."POS Terminal No." := LscPosTransaction."POS Terminal No.";
            InsertPOSTransLine."Receipt No." := LscPosTransaction."Receipt No.";
            InsertPOSTransLine."Line No." := 1;
            InsertPOSTransLine."Entry Type" := InsertPOSTransLine."Entry Type"::FreeText;
            InsertPOSTransLine.Description := 'CallCenter';
            InsertPOSTransLine.INSERT(True);
        END;
    end;

    procedure OpenOrderPOS(OrderNoPos: Code[20])
    var
        LastSlipNo: Code[20];
        OrderNo: Code[20];
        TransHdr: Record "LSC Transaction Header";
        PosTrans: Record "LSC POS Transaction";
        LocalStore: Record "LSC Store";
        CallCenterPOSTermAssignm: Record "LSC CC POS Term. Assignm.";
        Text089: Label 'No se encontró ninguna entrada en la tabla %1 para el centro de llamadas %2 y el restaurante %3';
        Text085: Label 'Se debe dedicar un %1 para el centro de llamadas %2 y el restaurante %3 en la tabla %4';
        Text090: Label 'Ocurrió un error al insertar en la tabla %1. Intentar otra vez.';
        DelOrder: Record "LSC Delivery Order";
        PosTerminal: Record "LSC POS Terminal";
        PosFunc: Codeunit "LSC POS Functions";
        SalesType: Integer;
        SalesTypes: Record "LSC Sales Type";
        POSTransaction: Record "LSC POS Transaction";
        OrderDateTime: DateTime;
        errorText: Text;
        POSMenuLineTemp: Record "LSC POS Menu Line";
        HosPosStartup: Codeunit "LSC Hospitality POS Startup";
        RetailSetup_l: Record "LSC Retail Setup";
        NoSeriesMgt: Codeunit NoSeriesManagement;

    begin

        GlobalMenuLine."Menu ID" := '#HOSP-ORDEREDIT-CC';
        GlobalMenuLine.Command := 'HOSP-ORDEREDIT';
        GlobalMenuLine."Current-RECEIPT" := OrderNoPos;
        GlobalMenuLine."Key No." := 1;
        HosPosStartup.Run(GlobalMenuLine);
        //CurrPage.Close();
        POSSESSION.SetValue('CURRORDER', OrderNoPos);
        POSSESSION.SetValue('CLEARCURRORDER', 'false');
        HosPosStartup.DirectEdit(true);
    end;

    procedure PROCESSPOS(orderNo: Code[20])
    var
        myInt: Integer;
        HosPosStartup: Codeunit "LSC Hospitality POS Startup";
    begin
        POSSESSION.SetValue('CURRORDER', orderNo);
        GlobalMenuLine."Menu ID" := '#HOSP-ORDEREDIT-CC';
        GlobalMenuLine.Command := 'HOSP-ORDEREDIT';
        GlobalMenuLine."Key No." := 1;
        HosPosStartup.Run(GlobalMenuLine);
        HosPosStartup.DirectEdit(true);
    end;

    procedure InsertTmpTrans(var LastSlipNo: Code[20]; ShiftNo: Code[1]; SetSalesType: Code[20]; TableNo: Integer; TrainingActive: Boolean; TableDescr: Text) NewSlipNo: Code[20]
    var
        TmpTrans: Record "LSC POS Transaction";
        SalesTypes: Record "LSC Sales Type";
        Seq: Integer;
        LoopCount: Integer;
        InsertOK: Boolean;
        StoreSetup: Record "LSC Store";
        LocalizationExt: Codeunit "LSC Retail Localization Ext.";
    begin

        TmpTrans.Init();
        StoreSetup.Get('F20');
        if TmpTrans.RecordLevelLocking then
            TmpTrans.LockTable();

        TmpTrans."Receipt No." := LastSlipNo;
        TmpTrans."New Transaction" := true;
        TmpTrans."Store No." := POSSESSION.StoreNo;
        TmpTrans."POS Terminal No." := POSSESSION.TerminalNo;
        TmpTrans."Created on POS Terminal" := POSSESSION.TerminalNo;
        TmpTrans."Staff ID" := POSSESSION.StaffID;
        TmpTrans."Shift No." := ShiftNo;
        TmpTrans."Gen. Bus. Posting Group" := StoreSetup."Store Gen. Bus. Post. Gr.";
        TmpTrans."VAT Bus.Posting Group" := StoreSetup."Store VAT Bus. Post. Gr.";
        if LocalizationExt.IsNALocalizationEnabled then begin
            TmpTrans."Tax Area Code" := StoreSetup."Tax Area Code";
            TmpTrans."Tax Liable" := StoreSetup."Tax Liable";
        end;
        TmpTrans."Sale Is Return Sale" := false;
        TmpTrans."Sales Type" := SetSalesType;
        TmpTrans."Table No." := TableNo;

        TmpTrans."Dining Tbl. Description" := TableDescr;

        if TrainingActive then
            TmpTrans."Entry Status" := TmpTrans."Entry Status"::Training
        else
            TmpTrans."Entry Status" := TmpTrans."Entry Status"::" ";

        if SetSalesType <> '' then
            if SalesTypes.Get(SetSalesType) then begin
                if SalesTypes."VAT Bus. Posting Group" <> '' then
                    TmpTrans.Validate("VAT Bus.Posting Group", SalesTypes."VAT Bus. Posting Group");
                if SalesTypes."Price Group" <> '' then
                    TmpTrans.Validate(TmpTrans."Price Group Code", SalesTypes."Price Group");
            end;

        TmpTrans."Hosp. Type Sequence" := 0;
        if Evaluate(Seq, POSSESSION.GetValue('HOSTYPSEQ')) then
            TmpTrans."Hosp. Type Sequence" := Seq;

        LoopCount := 0;
        InsertOK := false;

        TmpTrans.Insert(true);
        Commit;
        exit(TmpTrans."Receipt No.");
    end;

    //Actualiza direccion en delivery order dependiendo del tipo domicilio.
    procedure UpdateAdressDelOrder()
    var
        SalesType: Integer;
        DelOrder: Record "LSC Delivery Order";
        SalesTypes: Record "LSC Sales Type";
        POSTransaction: Record "LSC POS Transaction";
    begin
        CASE DomicilioTake OF
            DomicilioTake::Home:
                SalesType := 1;
            DomicilioTake::Work:
                SalesType := 2;
            DomicilioTake::Other:
                SalesType := 3;
            DomicilioTake::Takeout:
                SalesType := 4;
        END;
        DelOrder.Reset();
        IF DelOrder.Get(POSSESSION.GetValue('CURRORDER')) then begin
            DelOrder.Validate("Order Type Option", SalesType);
            if SalesTypes.Get(DelOrder."Sales Type") then begin
                IF POSTransaction.Get(POSSESSION.GetValue('CURRORDER')) THEN BEGIN
                    if SalesTypes."VAT Bus. Posting Group" <> '' then
                        POSTransaction."VAT Bus.Posting Group" := SalesTypes."VAT Bus. Posting Group";
                    if SalesTypes."Price Group" <> '' then
                        POSTransaction."Price Group Code" := SalesTypes."Price Group";
                    POSTransaction."Sales Type" := SalesTypes.Code;
                    POSTransaction.Modify(true);
                    Commit();
                END;
            end;

            if not (Globals."General Status" = Globals."General Status"::ERROR) then
                If not ((DelOrder."Call Cent. Web Service Status" IN [DelOrder."Call Cent. Web Service Status"::"Cancelled-Sent",
                                                   DelOrder."Call Cent. Web Service Status"::"Changed-Sent", DelOrder."Call Cent. Web Service Status"::"New-Sent"])) THEN begin
                    DelOrder."Restaurant No." := Restaurante;
                end else begin
                    Estatus := Format(DelOrder."Call Cent. Web Service Status"::"Changed-Sent");
                    DelOrder."Call Cent. Web Service Status" := DelOrder."Call Cent. Web Service Status"::"Changed-Sent";
                end;
            DelOrder.Address := AddressV;
            DelOrder."Address 2" := Address2V;
            DelOrder.City := InputCity;
            DelOrder."Created at Call Center" := 'F20';
            DelOrder."Post Code" := InputZipCode;
            DelOrder.Directions := DirectionsV;
            DelOrder."FSN Directions" := DirectionsV2;
            DelOrder."Grid Code" := InputGrid;
            DelOrder."Sales Type" := SalesTypes.Code;
            DelOrder."FSN Alter Key" := FSNAlterKey;
            DelOrder."FSN Street Name" := AddressV;
            DelOrder.Modify();
            Commit();
            Globals.Reset();
            Globals := DelOrder;
        end;
    end;

    //llena variable Global para levantar el POS
    procedure SetPosmenuLine(POSMenuLine: Record "LSC POS Menu Line");
    var
        myInt: Integer;
        pd: Record "LSC Posted Delivery Order";
    begin
        GlobalMenuLine.Copy(POSMenuLine);

    end;

    //Valida Hora de cierre del restaurante y el estado de la orden para cambiar hora.
    procedure ValidateTimeOnRestChange(var ContTmp: Record Contact; var ErrorText: Text; FromWS: Boolean)
    var
        OrderDateTime: DateTime;
        SText061: Label 'El restaurante %1 está cerrado dentro del período de %2 a %3.\Seleccione otro restaurante o cambie la hora del pedido.';
        SText025: Label 'El restaurante %1 no está abierto en %2.\Seleccione otra tienda o cambie la hora del pedido.';
        IsOpen: Boolean;
        DebugText: Text[250];
    begin
        if ContTmp."LSC Pre-Order Print DateTime" = 0DT then begin    //not a pre-order
            // Usar la fecha/hora ingresada por el usuario si existe; no sobreescribir con la fecha/hora actual
            if (ContTmp."LSC Next Order Date" <> 0D) then
                OrderDateTime := CreateDateTime(ContTmp."LSC Next Order Date", ContTmp."LSC Next Order Time")
            else
                OrderDateTime := CurrentDateTime;
            OrderProdTime := 0;
            IsOpen := IsStoreOpenAt(ContTmp."LSC Next Order Restaurant", DT2Date(OrderDateTime), DT2Time(OrderDateTime), DebugText);
            if not IsOpen then begin
                ErrorText := StrSubstNo(SText025, ContTmp."LSC Next Order Restaurant", DT2Time(OrderDateTime));
                exit;
            end;
            ContTmp."LSC Next Estimated Prod. Time" := 0;
        end else begin            // a pre-order
            OrderDateTime := CreateDateTime(ContTmp."LSC Next Order Date", ContTmp."LSC Next Order Time");
            OrderProdTime := 0;
            IsOpen := IsStoreOpenAt(ContTmp."LSC Next Order Restaurant", DT2Date(OrderDateTime), DT2Time(OrderDateTime), DebugText);
            if not IsOpen then begin
                ErrorText := StrSubstNo(SText025, ContTmp."LSC Next Order Restaurant", DT2Time(OrderDateTime));
                exit;
            end;
            ContTmp."LSC Pre-Order Print DateTime" := OrderDateTime - (5 * 60000);
            ContTmp."LSC Next Estimated Prod. Time" := 0;
        end;
        if ErrorText <> '' then
            POSSESSION.SetValue('VALRESTAURAN', 'TRUE')
        ELSE
            POSSESSION.SetValue('VALRESTAURAN', 'FALSE')
        //SetDate(ContTmp."LSC Next Order Date", ContTmp."LSC Next Order Time", false);
    end;

    procedure OrderTypeOptionValue(): Boolean
    var
        myInt: Integer;
        RetalCalendar: Record "LSC Retail Calendar";
        RetailCalendarLine: Record "LSC Retail Calendar Line";
    begin
        //28981
        IF DomicilioTake = DomicilioTake::Takeout then begin
            RetalCalendar.SetCurrentKey("Calendar Type", "Group Type", ID);
            RetalCalendar.SetRange("Calendar Type", RetalCalendar."Calendar Type"::"Rest. Order Taking");
            RetalCalendar.SetRange("Group Type", RetalCalendar."Group Type"::Store);
            RetalCalendar.SetRange(ID, Globals."Restaurant No.");
            if RetalCalendar.FindFirst() then begin
                RetailCalendarLine.reset;
                RetailCalendarLine.SetRange(RetailCalendarLine."Calendar Type", RetalCalendar."Calendar Type");
                RetailCalendarLine.SetRange(RetailCalendarLine."Group Type", RetalCalendar."Group Type");
                RetailCalendarLine.SetRange(RetailCalendarLine."Calendar ID", RetalCalendar.ID);
                if RetailCalendarLine.FindFirst() then
                    exit(true)
                else
                    exit(false);
            end else
                exit(false);
        end else
            exit(false);
    end;

    procedure FindProductionTime(CalType: Option All,"Opening Hours",Receiving,"Rest. Order Taking",,,,Other; RestaurantNo: Code[10]; SchemeType: Option "Order","Product Group","Special Group",Item; SchemeCode: Code[20]; var DateTimeIn: DateTime; TimeCalc: Option Finish,Start; var ErrorText: Text[250]; GetEstimJobOnCC: Boolean; var ProdTimeLength: Integer; var TimeFrom: DateTime; var TimeTo: DateTime; var OpenStatus: Option Open,"Closed within Period","Closed at End Point"): Boolean
    var
        ProdTimingScheme: Record "LSC Rest. Prod. Timing Scheme";
        Store: Record "LSC Store";
        HospSetup: Record "LSC Hospitality Setup";
        RetailCalMgt: Codeunit "LSC Retail Calendar Management";
        MultiFactor: Integer;
        LoadLevel: Option Medium,Low,High,Intense,"None";
        Precision: BigInteger;
        Text001: Label 'El valor del campo %1 en %2 no está establecido.';
        FloorDT: DateTime;
        CheckDT: DateTime;
        CheckTime: Time;
    begin
        ErrorText := '';
        FloorDT := RoundDateTime(DateTimeIn, 60000, '<');
        CheckDT := DateTimeIn;
        if CheckDT = FloorDT then begin
            if DT2Time(CheckDT) <> 235900T then
                CheckDT := CheckDT + 1000; // +1 segundo para incluir el inicio del tramo
        end;
        CheckTime := DT2Time(CheckDT);

        case TimeCalc of
            TimeCalc::Finish:
                begin
                    MultiFactor := 1;
                    TimeFrom := DateTimeIn;
                end;
            TimeCalc::Start:
                begin
                    MultiFactor := -1;
                    TimeTo := DateTimeIn;
                end;
        end;
        Store.Get(RestaurantNo);
        case Store."Time Rounding Precision" of
            Store."Time Rounding Precision"::"No Rounding":
                Precision := 1000;
            Store."Time Rounding Precision"::"5 min":
                Precision := 1000 * 60 * 5;
            Store."Time Rounding Precision"::"10 min":
                Precision := 1000 * 60 * 10;
            Store."Time Rounding Precision"::"15 min":
                Precision := 1000 * 60 * 15;
            Store."Time Rounding Precision"::"20 min":
                Precision := 1000 * 60 * 20;
            Store."Time Rounding Precision"::"30 min":
                Precision := 1000 * 60 * 30;
        end;
        ProdTimeLength := 0;

        if not RetailCalMgt.StoreOpenAtTime(RestaurantNo, CalType, DT2Date(CheckDT), CheckTime) then begin
            OpenStatus := OpenStatus::"Closed at End Point";
            exit(false);
        end;

        if (TimeCalc = TimeCalc::Finish) and (Store."Normal Order Timing" = Store."Normal Order Timing"::"Estimated Timing") then begin
            if not GetEstimJobOnCC then begin
                Store.CalcFields("Estim. Prod. Time");
                Store."Rest. Estim. Prod. Time (Min.)" := Store."Estim. Prod. Time";
            end;
            ProdTimeLength := Round(Store."Rest. Estim. Prod. Time (Min.)", 1);
            if (ProdTimeLength < Store."Max. Order Timing (Min.)") and (ProdTimeLength <> 0) then begin
                if DateTimeIn <= CurrentDateTime then
                    DateTimeIn := RoundDateTime(DateTimeIn + (MultiFactor * ProdTimeLength * 60000), Precision, '>');
                case TimeCalc of
                    TimeCalc::Finish:
                        TimeTo := DateTimeIn;
                    TimeCalc::Start:
                        TimeFrom := DateTimeIn;
                end;
                RetailCalMgt.GetStoreOpenStatusInPeriod(
                  RestaurantNo, CalType, TimeFrom, TimeTo, OpenStatus);
                exit((OpenStatus = OpenStatus::Open));
            end;
        end;

        LoadLevel := FindProductionLoad(RestaurantNo, DT2Date(CheckDT), CheckTime, TimeCalc);

        if ProdTimingScheme.Get(RestaurantNo, SchemeType, SchemeCode) and
           (LoadLevel in [LoadLevel::Low, LoadLevel::Medium, LoadLevel::High, LoadLevel::Intense])
        then begin
            case LoadLevel of
                LoadLevel::Low:
                    ProdTimeLength := ProdTimingScheme."Low Load Prod. Time (Min.)";
                LoadLevel::Medium:
                    ProdTimeLength := ProdTimingScheme."Medium Load Prod. Time (Min.)";
                LoadLevel::High:
                    ProdTimeLength := ProdTimingScheme."High Load Prod. Time (Min.)";
                LoadLevel::Intense:
                    ProdTimeLength := ProdTimingScheme."Intense Load Prod. Time (Min.)";
            end;
            if DateTimeIn <= CurrentDateTime then
                DateTimeIn := RoundDateTime(DateTimeIn + (MultiFactor * ProdTimeLength * 60000), Precision, '>');
            case TimeCalc of
                TimeCalc::Finish:
                    TimeTo := DateTimeIn;
                TimeCalc::Start:
                    TimeFrom := DateTimeIn;
            end;
            RetailCalMgt.GetStoreOpenStatusInPeriod(
              RestaurantNo, CalType, TimeFrom, TimeTo, OpenStatus);
            exit((OpenStatus = OpenStatus::Open));
        end else begin

            HospSetup.Get;
            if HospSetup."Order Process Time (Min.)" <> 0 then begin
                ProdTimeLength := HospSetup."Order Process Time (Min.)";
                if DateTimeIn <= CurrentDateTime then
                    DateTimeIn := RoundDateTime(DateTimeIn + (MultiFactor * ProdTimeLength * 60000), Precision, '>');
                case TimeCalc of
                    TimeCalc::Finish:
                        TimeTo := DateTimeIn;
                    TimeCalc::Start:
                        TimeFrom := DateTimeIn;
                end;
                RetailCalMgt.GetStoreOpenStatusInPeriod(
                  RestaurantNo, CalType, TimeFrom, TimeTo, OpenStatus);
                exit((OpenStatus = OpenStatus::Open));
            end else begin
                if DateTimeIn <= CurrentDateTime then
                    DateTimeIn := 0DT;
                ErrorText := StrSubstNo(Text001, HospSetup.FieldCaption("Order Process Time (Min.)"), HospSetup.TableCaption);
                exit(false);
            end;
        end;
    end;

    procedure FindProductionLoad(Restaurant: Code[10]; DateIn: Date; TimeIn: Time; TimeCalc: Option Finish,Start): Integer
    var
        CurrentLoadSchedule: Record "LSC Rest. Current Load Schd";
        DefaultLoadSchedule: Record "LSC Rest. Default Load Schd";
        DayOfWeek: Integer;
    begin
        CurrentLoadSchedule.Reset;
        CurrentLoadSchedule.SetRange("Store No.", Restaurant);
        CurrentLoadSchedule.SetRange(Date, DateIn);
        if CurrentLoadSchedule.FindSet then begin
            repeat
                CurrentLoadSchedule.CalcFields("Time To");
                case TimeCalc of
                    TimeCalc::Finish:
                        if (TimeIn >= CurrentLoadSchedule."Time From") and (TimeIn < CurrentLoadSchedule."Time To") then
                            exit(CurrentLoadSchedule."Load Level");
                    TimeCalc::Start:
                        if (TimeIn > CurrentLoadSchedule."Time From") and (TimeIn <= CurrentLoadSchedule."Time To") then
                            exit(CurrentLoadSchedule."Load Level");
                end;
            until CurrentLoadSchedule.Next = 0;
        end;

        DefaultLoadSchedule.Reset;
        DefaultLoadSchedule.SetRange("Store No.", Restaurant);
        if DefaultLoadSchedule.FindSet then begin
            repeat
                case TimeCalc of
                    TimeCalc::Finish:
                        if (TimeIn >= DefaultLoadSchedule."Time From") and (TimeIn < DefaultLoadSchedule."Time To") then begin
                            DayOfWeek := Date2DWY(DateIn, 1);
                            case DayOfWeek of
                                1:
                                    exit(DefaultLoadSchedule."Monday Load");
                                2:
                                    exit(DefaultLoadSchedule."Tuesday Load");
                                3:
                                    exit(DefaultLoadSchedule."Wednesday Load");
                                4:
                                    exit(DefaultLoadSchedule."Thursday Load");
                                5:
                                    exit(DefaultLoadSchedule."Friday Load");
                                6:
                                    exit(DefaultLoadSchedule."Saturday Load");
                                7:
                                    exit(DefaultLoadSchedule."Sunday Load");
                            end;
                        end;
                    TimeCalc::Start:
                        if (TimeIn > DefaultLoadSchedule."Time From") and (TimeIn <= DefaultLoadSchedule."Time To") then begin
                            DayOfWeek := Date2DWY(DateIn, 1);
                            case DayOfWeek of
                                1:
                                    exit(DefaultLoadSchedule."Monday Load");
                                2:
                                    exit(DefaultLoadSchedule."Tuesday Load");
                                3:
                                    exit(DefaultLoadSchedule."Wednesday Load");
                                4:
                                    exit(DefaultLoadSchedule."Thursday Load");
                                5:
                                    exit(DefaultLoadSchedule."Friday Load");
                                6:
                                    exit(DefaultLoadSchedule."Saturday Load");
                                7:
                                    exit(DefaultLoadSchedule."Sunday Load");
                            end;
                        end;
                end;
            until DefaultLoadSchedule.Next = 0;
        end;

        exit(99); //No Load Schedule exists for the specified time
    end;

    //Resive el numero de orden y envia pedido WS a restaurante
    procedure ProcessOrderT(OrderNo: Code[20])
    var
        myInt: Integer;
        DelOrd: Record "LSC Delivery Order";
        OfflineCCSetup: Record "LSC Offline Call Center Setup";
        DelCont: Record Contact;
        DelOrderM: Codeunit "LSC Delivery Order Management";
        DelPosComm: Codeunit "LSC Delivery POS Commands";
        DelOrderChanges: Boolean;
        PosTrChange: Boolean;
        PosTrFound: Boolean;
        ErrorText: Text;
        Windows: Dialog;
        Text056: Label 'Enviado al restaurante con éxito.';
        Text055: Label 'Pedido en espera de envio automatico';
        Text054: Label 'Sala no esta abierta';
        Text025: Label 'El restaurante %1 no está abierto en %2.\Seleccione otra tienda o cambie la hora del pedido.';
        LoadingText: Label 'Procesando Pedido, Espere.......';
        FSNSalesChannel: Record "FSN Sales Channel";
        lText002: Label 'Debe establecerse un canal de ventas';
        Text000D: Label 'La última hora válida para la calle %1 es %2.\%3';
        SendToCallCenter: Boolean;
        POSCARD: Record "LSC POS Card Entry";
        PosTrans: record "LSC POS Transaction";
        WsTable: Record "FSN WebServiceTable";
        sendOrder: Codeunit "FSN Call Center SenOrder";
        CalendarValidationError: Text[250];
        CalendarDebugMsg: Text[250];
    begin
        PosTrChange := false;
        PosTrFound := true;
        Windows.OPEN(LoadingText);
        Windows.UPDATE;
        DelOrd.Reset();

        if not FSNSalesChannel.Get(OrderNo) then begin
            Message(lText002);
            exit;
        end;
        ValidateStaff(OrderNo);
        ValidateStore();

        SendToCallCenter := false;
        ValTime(OrderNo);
        if DelOrd.Get(OrderNo) then;

        // ACTUALIZAR Globals con los valores actuales de fecha/hora editados en los controles
        // (Están guardados en POSSESSION por los triggers OnValidate)
        Globals."Order Date" := DateOrder;
        Globals."Contact Pickup Time" := TimeOrder;

        // NUEVA VALIDACIÓN: Usar la lógica de 6 pasos con Cerrado/Temporal/Normal e Include All Week Days
        if not FSNDeliveryFunct.ValidateStoreOpenForDeliveryOrder(Globals, CalendarValidationError, CalendarDebugMsg) then begin
            Windows.Close();
            Message(StrSubstNo(Text025, Globals."Restaurant No.", Format(TimeOrder)));
            exit;
        end;

        if DelOrd.Get(OrderNo) then begin

            DelStreet_l.RESET;
            DelStreet_l.SETRANGE(DelStreet_l."FSN Alter Key", DelOrd."FSN Alter Key");
            IF DelStreet_l.FINDFIRST THEN begin
                IF (DelStreet_l."FSN Last Valid Time" <> 0T) AND (DelOrd."Contact Pickup Time" > DelStreet_l."FSN Last Valid Time") THEN BEGIN
                    Message(STRSUBSTNO(Text000D, DelStreet_l."Street Name", FORMAT(DelStreet_l."FSN Last Valid Time"), DelStreet_l.Restriction));
                    exit;
                END;
            end;
            DelCont.Reset();
            if DelCont.get(DelOrd."Phone No.") then begin
                DelCont."LSC Next Order Selection" := DelOrd."Order Type Option";
                DelCont."LSC Next Order Restaurant" := DelOrd."Restaurant No.";
                DelCont."LSC Next Order Date" := DelOrd."Order Date";
                if DelOrd."Pre-Order" = DelOrd."Pre-Order"::"On Hold" then begin
                    DelCont."LSC Next Order Time" := DelOrd."Contact Pickup Time";
                end else
                    DelCont."LSC Next Order Time" := Time;
                DelCont."LSC Next Delivery Tender" := DelOrd."Tender Type";
                DelCont."LSC Pre-Order Print DateTime" := DelOrd."Pre-Order Print DateTime";
                DelCont."LSC Next Estimated Prod. Time" := DelOrd."Estimated Prod. Time (Min.)";
                DelCont.Modify;
                DelOrderM.UpdateOrder(OrderNo, DelCont, false, false, true);
            end;

            if (DelOrd."Call Cent. Web Service Status" = DelOrd."Call Cent. Web Service Status"::"New-Not Sent") or
   (DelOrd."Call Cent. Web Service Status" = DelOrd."Call Cent. Web Service Status"::"New-Not Confirmed") or
   (DelOrd."Call Cent. Web Service Status" = DelOrd."Call Cent. Web Service Status"::"New-Sent") or
   (DelOrd."Call Cent. Web Service Status" = DelOrd."Call Cent. Web Service Status"::"Changed-Sent") or
   (DelOrd."Call Cent. Web Service Status" = DelOrd."Call Cent. Web Service Status"::"Changed-Not Sent") then
                SendToCallCenter := true;

            if SendToCallCenter then begin
                //if DelPosComm.SendDeliveryOrder(DelOrd, DelOrderChanges, ErrorText) then begin
                POSCARD.Reset();//crea linea para media de pago tarjeta
                POSCARD.SetRange("Receipt No.", DelOrd."Order No.");
                if POSCARD.FindFirst() then begin
                    RequestID := 'DEL-TRANSCARDFSN';
                    MsgResult := Format(DelOrd."General Status");
                    XMLRequest := DelOrd."Order No.";
                    FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
                end;

                RequestID := 'DEL-TRANSFSN';//manda a DAF
                MsgResult := Format(DelOrd."General Status");
                XMLRequest := DelOrd."Order No.";
                FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);

                if SendDeliveryOrder(DelOrd, DelOrderChanges, ErrorText) then begin
                    OfflineCCSetup.Get;
                    DelOrd.Reset();
                    DelOrd.Get(OrderNo);

                    if DelOrd."Call Cent. Web Service Status" in
                      [DelOrd."Call Cent. Web Service Status"::"New-Not Sent", DelOrd."Call Cent. Web Service Status"::"New-Not Confirmed"] then
                        DelOrd."Call Cent. Web Service Status" := DelOrd."Call Cent. Web Service Status"::"New-Sent";

                    if DelOrd."Call Cent. Web Service Status" = DelOrd."Call Cent. Web Service Status"::"Changed-Not Sent" then
                        DelOrd."Call Cent. Web Service Status" := DelOrd."Call Cent. Web Service Status"::"Changed-Sent";


                    DelOrd."General Status" := DelOrd."General Status"::"In Process";
                    if (DelOrd."Assigned to Driver") or (DelOrd."Process Status" = DelOrd."Process Status"::Finished) then
                        DelOrd."General Status" := DelOrd."General Status"::Confirmed;

                    DelOrd.Modify();
                    Commit();
                    if WsTable.Get(OrderNo) then begin
                        if WsTable.Store in ['APP', 'EC'] then begin
                            IF WsTable."Status WS" <> WsTable."Status WS"::InProcess THEN begin
                                WsTable."Status WS" := WsTable."Status WS"::InProcess;
                                WsTable.Modify();
                                Commit();
                            end;
                        end;
                    end;
                    Commit;

                    if OfflineCCSetup."Show Msg. on Successful Send" then
                        Message(Text056);

                    POSSESSION.SetValue('CLEARCURRORDER', 'true');
                    CurrPage.Close();

                end else begin
                    DelOrd.Reset();
                    if DelOrd.Get(OrderNo) then begin
                        if DelOrd."Call Cent. Web Service Status" = DelOrd."Call Cent. Web Service Status"::"New-Not Confirmed" then
                            DelOrd."Call Cent. Web Service Status" := DelOrd."Call Cent. Web Service Status"::"New-Not Sent";
                        DelOrd."General Status" := DelOrd."General Status"::ERROR;
                        DelOrd.Modify();
                        Commit();
                        ProStyleStutus(Format(DelOrd."General Status"));
                    end;
                    Commit;

                    IF POSSESSION.GetValue('VALRESTAURAN') = 'TRUE' then
                        Message(Text054)
                    else
                        if POSSESSION.GetValue('VALRESTAURAN') = 'FALSE' then begin
                            Message(Text055);
                            CurrPage.Close();
                        end;
                end;
            end;
            Commit();
        end;
        Windows.Close();
    end;

    //Actualiza la orden si ya se habia enviado
    procedure SendDeliveryOrder(DelOrderToSend: Record "LSC Delivery Order"; DelOrderOnly: Boolean; var EstimErrorText: Text[1024]): Boolean
    var
        ProcessError: Boolean;
        CreateHospOrderUtils: Codeunit LSCCreateHospOrderUtils;
        ResponseCode: Code[30];
        ErrorText: Text;
    begin
        //si no se ha enviado
        if DelOrderToSend."Call Cent. Web Service Status" in
          [DelOrderToSend."Call Cent. Web Service Status"::"New-Not Sent",
          DelOrderToSend."Call Cent. Web Service Status"::"New-Not Confirmed",
          DelOrderToSend."Call Cent. Web Service Status"::"Changed-Not Sent"]
        then begin
            OfflineCCWSClient.SendDelOrder(DelOrderToSend."Order No.", DelOrderToSend."Restaurant No.", ProcessError, EstimErrorText);
            exit(not ProcessError);
        end;
        //si ya se envio y se desea reconfirmar
        if DelOrderToSend."Call Cent. Web Service Status" in [DelOrderToSend."Call Cent. Web Service Status"::"Changed-Sent",
        DelOrderToSend."Call Cent. Web Service Status"::"New-Sent"] then begin
            if DelOrderOnly then
                OfflineCCWSClient.SendDelOrderNoTrans(DelOrderToSend."Order No.", DelOrderToSend."Restaurant No.", ProcessError, EstimErrorText)
            else
                OfflineCCWSClient.SendDelOrder(DelOrderToSend."Order No.", DelOrderToSend."Restaurant No.", ProcessError, EstimErrorText);
            exit(not ProcessError);
        end;

        exit(true);
    end;

    //Actualiza el contacto
    procedure UpdateContact(ReceiptNo: Code[20])
    var
        ErrorText: Text;
        DelOrder: Record "LSC Delivery Order";
        DelCont: Record Contact;
    begin
        //EditOrder
        if DelOrder.Get(ReceiptNo) then begin
            POSSESSION.SetValue('CURRORDER', DelOrder."Order No.");

            DelContTEMP.Get(DelOrder."Phone No.");
            DelContTEMP."LSC Next Order Selection" := DelOrder."Order Type Option";
            DelContTEMP."LSC Next Order Restaurant" := DelOrder."Restaurant No.";
            DelContTEMP."LSC Next Order Date" := DelOrder."Order Date";
            DelContTEMP."LSC Next Order Time" := DelOrder."Contact Pickup Time";
            DelContTEMP."LSC Next Delivery Tender" := DelOrder."Tender Type";
            DelContTEMP."LSC Pre-Order Print DateTime" := DelOrder."Pre-Order Print DateTime";
            DelContTEMP."LSC Next Estimated Prod. Time" := DelOrder."Estimated Prod. Time (Min.)";
            DelContTEMP.Name := DelOrder.Name;
            DelContTEMP.Modify;
        end;
    end;

    procedure UpdateRestaurante(vRestaurant: Code[20]);
    var
        ActiveLocation: Record Location;
        Text010: Label 'Tienda %1, %2';
        Text011: Label 'Debe confirmar medio de pago';
        Text016: label 'no puede ser seleccionada';
        Text012: Label 'No puede cambiar sala en pedido enviado/cancelado en sala';
        errorText: text;
    begin
        // Mark store as manually selected when updated via UI
        StoreEditedManually := (vRestaurant <> '');
        if StoreEditedManually then
            SetManualForType(DomicilioTake, vRestaurant)
        else
            SetManualFlagForType(DomicilioTake, false);
        if Globals."Order No." <> '' then begin
            If Globals."Order No." = POSSESSION.GetValue('CURRORDER') then begin
                If (Globals."General Status" = Globals."General Status"::ERROR) OR ((Globals."Call Cent. Web Service Status" IN [Globals."Call Cent. Web Service Status"::"Cancelled-Sent",
                        Globals."Call Cent. Web Service Status"::"Changed-Sent", Globals."Call Cent. Web Service Status"::"New-Sent"])) THEN BEGIN
                    Restaurante := Globals."Restaurant No.";
                    exit;
                end;
            end;
        end;

        IF DelContTEMP.get(PhoneNo) THEN
            IF ChangeRestaurant(DelContTEMP, Restaurante) THEN BEGIN
                //if (DelContTEMP."LSC Next Order Restaurant" <> Restaurante) /*AND (NOT (DelContTEMP."LSC Next Order Restaurant" = 'F20'))*/ then begin
                if NOT (DelContTEMP."LSC Next Order Restaurant" = 'F20') then begin
                    if POSSESSION.GetValue('CURRORDER') <> '' then begin
                        FSNDeliveryFunct.ChangeStore(Globals."Order No.", Restaurante, 1);
                        if ValidatePaymentOrder then
                            Message(Text011);

                        IF DelContTEMP.get(PhoneNo) THEN;
                        // Suprimir mensajes internos en actualización de tienda para evitar doble pop-up
                        ValidateTimeOnRestChange(DelContTEMP, errorText, true);
                    end;
                end;
            END ELSE begin
                if POSSESSION.GetValue('CURRORDER') <> '' then begin
                    if Globals."Restaurant No." <> 'F20' THEN
                        Restaurante := Globals."Restaurant No."
                    ELSE
                        Restaurante := '';
                end else begin
                    IF DelContTEMP."LSC Next Order Restaurant" <> 'F20' THEN
                        Restaurante := DelContTEMP."LSC Next Order Restaurant"
                    ELSE
                        Restaurante := '';
                end;
            end;
        UpdateAddress(DomicilioTake);
        //DelOrdManagement.LoadContext(false);
    end;

    //Cancela el pedido o lo elimina localmente y en sala si existe el Rec.
    procedure OrderCancelPressed()
    var
        CanceledOrderNo: Code[20];
        ChangeMade: Option OrderLines,OrderType,Address,Cancel,OrderTime,Restaurant,RestAddr;
        DeliveryOrder: Record "LSC Delivery Order";
        DelPosComm: codeunit "LSC Delivery POS Commands";
        Text082: Label 'Esta seguro de que deseas cancelar el pedido?';
        Log: Record "FSN Change Log Transaction";
        pIsConvert: Boolean;
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        MsgResult: Text;
        POSMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: Boolean;
        CancelWSProcess: Boolean;

    begin
        if DeliveryOrder.get(POSSESSION.GetValue('CURRORDER')) then begin
            if not Confirm(Text082, false) then
                exit;


            IF Log.FIND('+') THEN
                Log."Entry No." := Log."Entry No." + 1;
            if Log."Entry No." = 0 then begin
                Log."Entry No." := 1;
            end;
            Log."Receipt No." := DeliveryOrder."Order No.";
            IF STRLEN(DeliveryOrder."Phone No.") > 10 THEN BEGIN
                // Empezar en la posición que deja los últimos 10 caracteres. Asegurar índice >= 1.
                Log."Phone No." := COPYSTR(DeliveryOrder."Phone No.", STRLEN(DeliveryOrder."Phone No.") - 9, 10);
            END ELSE
                Log."Phone No." := DeliveryOrder."Phone No.";
            Log.Date := TODAY;
            Log."Log Time" := TIME;
            Log."User ID" := USERID;
            Log."Staff ID" := POSSESSION.StaffID();
            Log."Type of Change" := Log."Type of Change"::Deletion;
            If Log."Type of Change" = Log."Type of Change"::Deletion then begin
                Log.Action := 'Cancelar';
            end;
            Log.INSERT();

            if not DelOrdManagement.CheckChangeAllowed(ChangeMade::Cancel) then
                exit;

            if DeliveryOrder."Call Cent. Web Service Status" in [DeliveryOrder."Call Cent. Web Service Status"::"New-Not Confirmed"] then
                CancelWSProcess := false
            else
                CancelWSProcess := true;

            if not DelPosComm.ProcessCancelOrder(DeliveryOrder, CancelWSProcess) then
                exit;

            RequestID := 'DEL-CANCELDAF';
            MsgResult := Format(DeliveryOrder."General Status");
            XMLRequest := DeliveryOrder."Order No.";
            FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);

            POSCARD.Reset();
            POSCARD.SetRange("Receipt No.", DeliveryOrder."Order No.");
            IF POSCARD.Find('-') then begin
                RequestID := 'DEL-CANCELCARD';
                MsgResult := Format(DeliveryOrder."General Status");
                XMLRequest := DeliveryOrder."Order No.";
                FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
            end;


            FSNDeliveryFunct.DPCProcessOrderCancel(POSSESSION.GetValue('CURRORDER'));

            POSSESSION.SetValue('CLEARCURRORDER', 'true');
            CurrPage.Close();
        end else begin
            FSNDeliveryFunct.DPCProcessOrderCancel(POSSESSION.GetValue('CURRORDER'));
            POSSESSION.SetValue('CLEARCURRORDER', 'true');
            CurrPage.Close();
        end;
    end;

    procedure ValTime(OrdN: Code[20])
    var
        myInt: Integer;
        PosTrans: Record "LSC POS Transaction";
        HospSetup: Record "LSC Hospitality Setup";
        DelOrderIn: Record "LSC Delivery Order";
    begin
        if DelOrderIn.Get(OrdN) then begin
            if (DelOrderIn."Order Date" <= Today) and (DelOrderIn."Contact Pickup Time" < Time) then begin
                DelOrderIn."Order Date" := Today;
                DelOrderIn."Contact Pickup Time" := Time;
                DelOrderIn.Modify();
                Commit();
            end;
            POSSESSION.SetValue('DEL-PickupDate', Format(DelOrderIn."Order Date"));
            // Guardar hora con formato estándar
            POSSESSION.SetValue('DEL-PickupTime', Format(DelOrderIn."Contact Pickup Time"));
            Commit();  // COMMIT para asegurar persistencia en POSSESSION
        end;
    end;

    procedure ValidateStaff(Receip: Code[20])
    var
        PosTransacc: Record "LSC POS Transaction";
        DeliveyOrder: Record "LSC Delivery Order";
        PosInfoEntry: Record "LSC POS Trans. Infocode Entry";
        PosTransLine: Record "LSC POS Trans. Line";
        Parameter: Record "FSN Parameter";
    begin
        Parameter.Reset();
        parameter.SetRange("Grupo", 'STAFF');
        parameter.SetRange(Codigo, 'OK');
        if parameter.FindFirst() and (parameter.Activo) then begin
            PosInfoEntry.Reset();
            PosInfoEntry.SetRange("Receipt No.", Receip);
            PosInfoEntry.SetRange(Infocode, 'DNAME');
            PosInfoEntry.SetFilter("Staff ID", '<>%1', '');
            if PosInfoEntry.FindFirst() then;

            if PosTransacc.Get(Receip) then begin
                if (PosTransacc."Sales Staff" = '') or (PosTransacc."Sales Staff" <> PosTransacc."Staff ID") then begin
                    if PosInfoEntry."Staff ID" <> '' then begin
                        PosTransacc."Sales Staff" := PosInfoEntry."Staff ID";
                        PosTransacc."Staff ID" := PosInfoEntry."Staff ID";
                        PosTransacc.Modify(true);
                    end else begin
                        PosTransacc."Sales Staff" := POSSESSION.StaffID();
                        PosTransacc."Staff ID" := POSSESSION.StaffID();
                        PosTransacc.Modify(true);
                    end;
                end;
            end;

            if DeliveyOrder.Get(Receip) then begin
                if DeliveyOrder."Order Taker" = '' then
                    if PosInfoEntry."Staff ID" <> '' then begin
                        DeliveyOrder."Order Taker" := PosInfoEntry."Staff ID";
                        PosTransacc.Modify(true);
                    end else begin
                        DeliveyOrder."Order Taker" := POSSESSION.StaffID();
                        DeliveyOrder.Modify(true);
                    end;
            end;

            PosTransLine.Reset();
            PosTransLine.SetRange("Receipt No.", Receip);
            PosTransLine.SetRange("Entry Status", PosTransLine."Entry Status"::" ");
            PosTransLine.SetRange("Entry Type", PosTransLine."Entry Type"::Item);
            PosTransLine.SetFilter("Sales Staff", '=%1', '');
            if PosTransLine.Find('-') then begin
                repeat
                    PosTransLine."Sales Staff" := PosInfoEntry."Staff ID";
                    PosTransLine.Modify(true);
                    Commit();
                until PosTransLine.Next() = 0;
            end;
        end;
    end;


    local procedure SetManualFlagForType(AddressType: Option Home,Work,Other,Takeout; IsManual: Boolean)
    begin
        case AddressType of
            DomicilioTake::Home:
                begin
                    IsManualHome := IsManual;
                    if not IsManual then
                        Clear(ManualStoreHome);
                    POSSESSION.SetValue('MANUAL_FLAG_HOME', Format(IsManual));
                end;
            DomicilioTake::Work:
                begin
                    IsManualWork := IsManual;
                    if not IsManual then
                        Clear(ManualStoreWork);
                    POSSESSION.SetValue('MANUAL_FLAG_WORK', Format(IsManual));
                end;
            DomicilioTake::Other:
                begin
                    IsManualOther := IsManual;
                    if not IsManual then
                        Clear(ManualStoreOther);
                    POSSESSION.SetValue('MANUAL_FLAG_OTHER', Format(IsManual));
                end;
        end;
    end;

    local procedure SetManualForType(AddressType: Option Home,Work,Other,Takeout; StoreCode: Code[10])
    begin
        if StoreCode = '' then begin
            SetManualFlagForType(AddressType, false);
            exit;
        end;
        case AddressType of
            DomicilioTake::Home:
                begin
                    ManualStoreHome := StoreCode;
                    IsManualHome := true;
                    POSSESSION.SetValue('MANUAL_STORE_HOME', StoreCode);
                    POSSESSION.SetValue('MANUAL_FLAG_HOME', 'TRUE');
                end;
            DomicilioTake::Work:
                begin
                    ManualStoreWork := StoreCode;
                    IsManualWork := true;
                    POSSESSION.SetValue('MANUAL_STORE_WORK', StoreCode);
                    POSSESSION.SetValue('MANUAL_FLAG_WORK', 'TRUE');
                end;
            DomicilioTake::Other:
                begin
                    ManualStoreOther := StoreCode;
                    IsManualOther := true;
                    POSSESSION.SetValue('MANUAL_STORE_OTHER', StoreCode);
                    POSSESSION.SetValue('MANUAL_FLAG_OTHER', 'TRUE');
                end;
        end;
    end;

    local procedure IsManualForType(AddressType: Option Home,Work,Other,Takeout): Boolean
    var
        flagTxt: Text;
    begin
        case AddressType of
            DomicilioTake::Home:
                begin
                    if not IsManualHome then begin
                        flagTxt := UpperCase(POSSESSION.GetValue('MANUAL_FLAG_HOME'));
                        exit(flagTxt = 'TRUE');
                    end else
                        exit(IsManualHome);
                end;
            DomicilioTake::Work:
                begin
                    if not IsManualWork then begin
                        flagTxt := UpperCase(POSSESSION.GetValue('MANUAL_FLAG_WORK'));
                        exit(flagTxt = 'TRUE');
                    end else
                        exit(IsManualWork);
                end;
            DomicilioTake::Other:
                begin
                    if not IsManualOther then begin
                        flagTxt := UpperCase(POSSESSION.GetValue('MANUAL_FLAG_OTHER'));
                        exit(flagTxt = 'TRUE');
                    end else
                        exit(IsManualOther);
                end;
        end;
        exit(false);
    end;

    local procedure GetManualStoreForType(AddressType: Option Home,Work,Other,Takeout): Code[10]
    var
        val: Text;
        codeVal: Code[10];
    begin
        case AddressType of
            DomicilioTake::Home:
                begin
                    if ManualStoreHome = '' then begin
                        val := POSSESSION.GetValue('MANUAL_STORE_HOME');
                        Evaluate(codeVal, val);
                        ManualStoreHome := codeVal;
                    end;
                    exit(ManualStoreHome);
                end;
            DomicilioTake::Work:
                begin
                    if ManualStoreWork = '' then begin
                        val := POSSESSION.GetValue('MANUAL_STORE_WORK');
                        Evaluate(codeVal, val);
                        ManualStoreWork := codeVal;
                    end;
                    exit(ManualStoreWork);
                end;
            DomicilioTake::Other:
                begin
                    if ManualStoreOther = '' then begin
                        val := POSSESSION.GetValue('MANUAL_STORE_OTHER');
                        Evaluate(codeVal, val);
                        ManualStoreOther := codeVal;
                    end;
                    exit(ManualStoreOther);
                end;
        end;
        exit('');
    end;

    local procedure ValidateStore()
    var
        myInt: Integer;
        PosTrans: Record "LSC POS Transaction";
        Parameter: Record "FSN Parameter";
    begin
        if Parameter.Get('DELIVERY', 'STORE') THEN
            if PosTrans.Get(Globals."Order No.") then begin
                if Globals."Restaurant No." <> PosTrans."Store No." then begin
                    FSNDeliveryFunct.ChangeStore(Globals."Order No.", Globals."Restaurant No.", 1);
                    valdPay(PosTrans);
                end;
            end;
    end;

    local procedure valdPay(PosTrans: Record "LSC POS Transaction")
    var
        myInt: Integer;
        Balance: Decimal;
        RealBalance: Decimal;
        POSLine: Record "LSC POS Trans. Line";
        DelOrd: Record "LSC Delivery Order";
        DELBalance: Decimal;
        RetailSetup_l: Record "LSC Retail Setup";
    begin
        RetailSetup_l.Get();
        if RetailSetup_l."FSN Is Local Receipt" and (RetailSetup_l."FSN Last Slipt No." <> '') then begin
            if Evaluate(DELBalance, POSSESSION.GetValue('Balance')) then begin
                if DELBalance = 0 then begin
                    POSLine.Reset();
                    POSLine.SetRange("Receipt No.", PosTrans."Receipt No.");
                    POSLine.SetRange("Entry Status", POSLine."Entry Status"::" ");
                    POSLine.SetRange(POSLine."Entry Type", POSLine."Entry Type"::Payment);
                    if POSLine.find('-') then
                        repeat
                            if POSLine."FSN Additional Action" = POSLine."FSN Additional Action"::ConfirmPayment then begin
                                POSLine."FSN Additional Action" := POSLine."FSN Additional Action"::Nothing;
                                POSLine.Modify();
                                Commit();
                            end
                        until POSLine.Next() = 0;
                end;
            end;
        end;
    end;
}