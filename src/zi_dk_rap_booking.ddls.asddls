@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Booking Bo View'
define view entity ZI_DK_RAP_BOOKING
  as select from zdk_rap_abook
  association to parent ZI_DK_RAP_TRAVEL  as _Travel     on  $projection.TravelUuid = _Travel.TravelUuid

  association [1..1] to /DMO/I_Customer   as _Customer   on  $projection.CustomerId = _Customer.CustomerID

  association [1..1] to /DMO/I_Carrier    as _Carrier    on  $projection.CarrierId = _Carrier.AirlineID

  association [1..1] to /DMO/I_Connection as _Connection on  $projection.CarrierId    = _Connection.AirlineID

                                                         and $projection.ConnectionId = _Connection.ConnectionID

  association [1..1] to /DMO/I_Flight     as _Flight     on  $projection.CarrierId    = _Flight.AirlineID

                                                         and $projection.ConnectionId = _Flight.ConnectionID

                                                         and $projection.FlightDate   = _Flight.FlightDate

  association [0..1] to I_Currency        as _Currency   on  $projection.CurrencyCode = _Currency.Currency
{
  key booking_uuid          as BookingUuid,
      travel_uuid           as TravelUuid,
      booking_id            as BookingId,
      booking_date          as BookingDate,
      customer_id           as CustomerId,
      carrier_id            as CarrierId,
      connection_id         as ConnectionId,
      flight_date           as FlightDate,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      flight_price          as FlightPrice,
      currency_code         as CurrencyCode,
      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      @Semantics.user.lastChangedBy: true
      last_changed_by       as LastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,
      /* associations */

      _Travel,

      _Customer,

      _Carrier,

      _Connection,

      _Flight,

      _Currency
}
