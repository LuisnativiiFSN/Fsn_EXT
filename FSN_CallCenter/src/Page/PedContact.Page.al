page 50087 "FSN Pedido contacto"
{
    ApplicationArea = All;
    Caption = 'FSN Restaurant';
    Editable = false;
    PageType = Document;
    SourceTable = "LSC Delivery Order";
    UsageCategory = Administration;
    RefreshOnActivate = true;

    layout
    {
        area(Content)
        {
            group(General)
            {
                repeater(Group)
                {
                    field(Sala; Rec."Restaurant No.")
                    {
                        ApplicationArea = All;
                        Caption = 'Sala';
                        Editable = false;
                    }
                    field("Call Cent. Web Service Status"; "Call Cent. Web Service Status")
                    {
                        ApplicationArea = All;
                        Caption = 'Estado del pedido';
                        Editable = false;
                    }
                    field("Phone No."; "Phone No.")
                    {
                        ApplicationArea = All;
                        Caption = 'Telefono';
                        Editable = false;
                    }
                    field("Order Date"; "Order Date")
                    {
                        ApplicationArea = All;
                        Caption = 'Fecha';
                        Editable = false;
                    }
                    field("Order Taker"; "Order Taker")
                    {
                        Editable = false;
                    }
                    field(Name; Name)
                    {
                        ApplicationArea = All;
                        Caption = 'Nombre';
                        Editable = false;
                    }
                    field("Amount Incl. VAT"; "Amount Incl. VAT")
                    {
                        ApplicationArea = All;
                        Caption = 'Monto';
                        Editable = false;
                    }
                    field("Time Created"; "Time Created")
                    {
                        ApplicationArea = All;
                        Caption = 'Hora envio';
                        Editable = false;
                    }
                    field("Order No."; Rec."Order No.")
                    {
                        Caption = 'No. Orden';
                        Editable = false;
                    }
                }
            }
        }
    }
    actions
    {
        area(Processing)
        {

            action("Seleccionar Orden")
            {
                Image = SendTo;
                Promoted = true;
                //PromotedIsBig = true;
                PromotedCategory = Process;
                trigger OnAction()
                var
                    myInt: Integer;
                    PageDeliveryTakeOrder: Page "FSN Take Order CC";
                begin
                    CurrPage.Close();
                    PageDeliveryTakeOrder.SETGLOBALVALUE(Rec);
                    POSSession.SetValue('PAGERUNTAKE', '0');
                    PageDeliveryTakeOrder.RUN;
                end;
            }
        }
    }
    var
        myInt: Integer;
        POSSESSION: Codeunit "LSC POS Session";
        DelOrd: Record "LSC Delivery Order";

    trigger OnClosePage()
    var
        myInt: Integer;
        PageDeliveryTakeOrder: Page "FSN Take Order CC";
        POSSESSION: Codeunit "LSC POS Session";
        oRp: Code[20];
    begin

        IF DelOrd.Get(POSSESSION.GetValue('CURRORDER')) then begin
            PageDeliveryTakeOrder.SETGLOBALVALUE(DelOrd);
        end else begin
            POSSESSION.SetValue('PHONEORDER', "Phone No.");
            PageDeliveryTakeOrder.SETGLOBALVALUE(DelOrd);
        end;
        if POSSession.GetValue('PAGERUNTAKE') = '1' then begin
            PageDeliveryTakeOrder.RUN;
        end
    end;

    trigger OnOpenPage()
    var
        myInt: Integer;
    begin
        POSSession.SetValue('PAGERUNTAKE', '1');
    end;

    procedure LastPedOrder(LastOrd: Record "LSC Delivery Order")
    var
    begin
        DelOrd.Get(LastOrd."Order No.")
    end;
}