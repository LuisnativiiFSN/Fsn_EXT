page 50057 "FSN Delivery Order List"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "LSC Delivery Order";
    Caption = 'FSN Delivery order list';

    layout
    {
        area(Content)
        {
            repeater(Orders)
            {
                field("Order No."; "Order No.")
                {
                    Caption = 'Order No.';
                }
                field("Phone No."; "Phone No.")
                {
                    Caption = 'Phone No.';
                }
                field("Order Date"; "Order Date")
                {
                    Caption = 'Order Date';
                }
                field("Contact Pickup Time"; "Contact Pickup Time")
                {
                    Caption = 'Contact Pickup Time';
                }
                field("Printed OK"; "Printed OK")
                {
                    Caption = 'Printed OK';
                }
                field("Assigned to Driver"; "Assigned to Driver")
                {
                    Caption = 'Assigned to Driver';


                }
                field("Time Assigned"; "Time Assigned")
                {
                    Caption = 'Time Assigned';
                }
                field(Delivered; Delivered)
                {
                    Caption = 'Delivered';
                }
                field("Driver ID"; "Driver ID")
                {
                    Caption = 'Driver ID';
                }
                field("Driver Phone No."; "Driver Phone No.")
                {
                    Caption = 'Driver Phone No.';
                }
                field(Address; Address)
                {
                    Caption = 'Address';
                }
                field("Address 2"; "Address 2")
                {
                    Caption = 'Address 2';
                }
                field(City; City)
                {
                    Caption = 'City';
                }
                field("Order Taker"; "Order Taker")
                {
                    Caption = 'Order Taker';
                }
                field("Restaurant No."; "Restaurant No.")
                {
                    Caption = 'Restaurant No.';
                }
                field("Sales Type"; "Sales Type")
                {
                    Caption = 'Sales Type';
                    TableRelation = "LSC Sales Type".Code;
                }
                field(Name; Name)
                {
                    Caption = 'Name';
                }
                field("Bill-to Name"; "Bill-to Name")
                {
                    Caption = 'Bill-to Name';
                }
                field("General Status"; "General Status")
                {

                }
                field("Pre-Order"; "Pre-Order")
                {
                    Caption = 'Pre-Order';

                }
                field("Amount Incl. VAT"; "Amount Incl. VAT")
                {
                    AutoFormatType = 1;
                    Caption = 'Amount Incl. VAT';
                    Editable = false;
                }
                field("Tender Type"; "Tender Type")
                {
                    Caption = 'Tender Type';

                }
                field("Pre-Order Print DateTime"; "Pre-Order Print DateTime")
                {
                    Caption = 'Pre-Order Print DateTime';
                }
                field("Time Created"; "Time Created")
                {
                    Caption = 'Time Created';
                }
                field("Date Created"; "Date Created")
                {
                    Caption = 'Date Created';
                }
                field("Time Back in Queue"; "Time Back in Queue")
                {
                    Caption = 'Time Back in Queue';
                }
                field("Gross Prod. Time (Min.)"; "Gross Prod. Time (Min.)")
                {
                    Caption = 'Gross Prod. Time (Min.)';

                }
                field("Process Status"; "Process Status")
                {
                    Caption = 'Process Status';

                }
                field("Production Timing (Min.)"; "Production Timing (Min.)")
                {
                    Caption = 'Production Timing (Min.)';

                }
                field("Delivery Timing (Min.)"; "Delivery Timing (Min.)")
                {
                    Caption = 'Delivery Timing (Min.)';
                }
                field("Date Assigned"; "Date Assigned")
                {
                    Caption = 'Date Assigned';
                }
                field("Estimated Prod. Time (Min.)"; "Estimated Prod. Time (Min.)")
                {
                    Caption = 'Estimated Prod. Time (Min.)';
                }
                field("Driver Name"; "Driver Name")
                {
                    Caption = 'Driver Name';
                }
                field("Order Taker Name"; "Order Taker Name")
                {
                    Caption = 'Order Taker Name';
                }
                field("Created at Call Center"; "Created at Call Center")
                {
                    Caption = 'Created at Call Center';
                    Editable = false;
                }
                field("Call Cent. Web Service Status"; "Call Cent. Web Service Status")
                {
                    Caption = 'Call Cent. Web Service Status';

                }
                field("Rest. Web Service Status"; "Rest. Web Service Status")
                {
                    Caption = 'Rest. Web Service Status';

                }
                field("Converted in Restaurant"; "Converted in Restaurant")
                {
                    Caption = 'Converted in Restaurant';
                }
                field("Status Changed in Rest."; "Status Changed in Rest.")
                {
                    Caption = 'Status Changed in Rest.';
                    OptionCaption = 'No,Changed,Changed-Sent';

                }
                field("Invoice No."; "Invoice No.")
                {
                    Caption = 'Invoice No.';
                    Editable = false;
                }
                field("Order Type Option"; "Order Type Option")
                {
                    Caption = 'Order Type Option';

                }
                field("Post Code"; "Post Code")
                {
                    Caption = 'Post Code';

                }
                field(Directions; Directions)
                {
                    Caption = 'Directions';
                }
                field("Grid Code"; "Grid Code")
                {
                    Caption = 'Grid Code';
                }
                field("Trip Counter"; "Trip Counter")
                {
                    Caption = 'Trip Counter';
                }
                field("External Order No."; "External Order No.")
                {
                    Caption = 'External Order No.';
                }
                field("FSN Alter Key"; "FSN Alter Key")
                {
                }
                field("FSN Cash Change"; "FSN Cash Change")
                {
                }
                field("FSN DS Restriction"; "FSN DS Restriction")
                {
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action("Delete All Orders")
            {
                ApplicationArea = All;

                trigger OnAction()
                var
                    DelOrders: Record "LSC Delivery Order";
                    POStransac: Record "LSC POS Transaction";
                begin
                    DelOrders.Reset();
                    DelOrders.DeleteAll(true);
                    POStransac.Reset();
                    POStransac.DeleteAll(true);
                end;
            }
        }
    }

    trigger OnDeleteRecord(): Boolean
    var
        postrans: Record "LSC POS Transaction";
    begin
        if (postrans.Get(Rec."Order No.")) then
            postrans.Delete(true);
    end;

    var
        myInt: Integer;
}