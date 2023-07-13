# axi_utils

Set of AXI utility modules that I have needed to develop for several projects.
This repo depends on the pulp axi interfaces https://github.com/pulp-platform/axi

# axiu_id_remap

This module modifies the ID signal of all channels according to a translation table provided as input signals.

It is useful to reduce the width of the IDs when not all IDs in the original ID space are used.
For example, lets say we have 2 bits of ID but only IDs `1` and `2` are used.
We can reduce the ID width to only 1 bit with the following translation tables:

### slv2mst
| original ID | remapped ID |
|-------------|-------------|
| 2'd0        | 1'b0 (not used) |
| 2'd1        | 1'b0 (used) |
| 2'd2        | 1'b1 (used) |
| 2'd3        | 1'b0 (not used) |
### mst2slv
| remapped ID | original ID |
|-------------|-------------|
| 1'b0        | 2'd1 |
| 1'b1        | 2'd2 |

# axiu_dyn_id_alloc

This module modifies the ID dynamically with a pool of limited IDs.
In-flight requests with equal original ID are guaranteed to have the same modified ID to respect original ordering.
However, two requests that are not issued in-flight may result in different ID on the master side of this module.

It is useful when the destination AXI network only supports smaller number of IDs than issued by the masters of the connected network.
IDs are requested dynamically, so any AXI master can issue requets with any ID value, and the number of in-flight requests is only limited by the supported number of IDs in the network.

## Parameters
| Name | Description |
|------|-------------|
| SLV_UNIQUE_IDS | Number of IDs that are issued in the slave side. Valid range is 0:(2**SLV_ID_WIDTH - 1). |
| MST_UNIQUE_IDS | Number of IDs allocated dynamically. Values on the master side range 0:MST_UNIQUE_IDS-1. |
| MAX_TXNS_PER_ID | Max number of in-flight requests per each master ID. |

## Considerations

This module instantiates `MST_UNIQUE_IDS` FIFOs with length `MAX_TXNX_PER_ID`, and tables with length `SLV_UNIQUE_IDS` to do translations. So, each parameter value should be reduced as much as possible.
