Every primitive should have an `extraData` in it's storage.

TODO: Think of a name for it. Some options:

- customData
- attributes
- extraData

There should be a function like `setExtraData(bytes32 key, bytes value)`

Primitive Emits an event `Lens_ExtraDataSet(bytes32 key, bytes value)` when the extra data is set.

--
TODO: Should we also have a `removeExtraData(bytes32 key)` function? To delete it? Or just set empty `` value?
(Probably no...)
