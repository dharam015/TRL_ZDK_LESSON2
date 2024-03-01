@EndUserText.label: 'Booking BO Projection View'
@AccessControl.authorizationCheck: #CHECK
@Metadata.allowExtensions: true
@Search.searchable: true
define view entity ZC_DK_RAP_BOOKING as projection on ZI_DK_RAP_BOOKING as Booking
{
    key BookingUuid,
    TravelUuid,
    @Search.defaultSearchElement: true
    BookingId,
    BookingDate,
    @Consumption.valueHelpDefinition: [{  entity: {
        name: '/DMO/I_Customer',
        element: 'CustomerID'
    } }]
    @ObjectModel.text.element: [ 'CustomerName' ]
    @Search.defaultSearchElement: true
    CustomerId,
    _Customer.LastName as CustomerName,
    @Consumption.valueHelpDefinition: [{entity: {name: '/DMO/I_Carrier', element: 'AirlineID' }}]
    @ObjectModel.text.element: ['CarrierName']
    CarrierId,
    _Carrier.Name as CarrierName,
    @Consumption.valueHelpDefinition: [{
        entity: {
            name: '/DMO/I_Flight',
            element: 'ConnectionID'
        },
        additionalBinding: [
        { localElement: 'CarrierId', element: 'AirlineID'},
        { localElement: 'FlightDate', element: 'FlightDate', usage: #RESULT},
        { localElement: 'FlightPrice', element: 'Price', usage: #RESULT},
        { localElement: 'CurrencyCode', element: 'CurrencyCode', usage: #RESULT}
        ]
    }]
    ConnectionId,
    FlightDate,
    @Semantics.amount.currencyCode:'CurrencyCode' 
    FlightPrice,
    @Consumption.valueHelpDefinition: [{entity: {name: 'I_Currency', element: 'Currency' }}]
    CurrencyCode,
    CreatedBy,
    LastChangedBy,
    LocalLastChangedAt,
    /* Associations */
    _Carrier,
    _Connection,
    _Currency,
    _Customer,
    _Flight,
    _Travel: redirected to parent ZC_DK_RAP_TRAVEL
}
